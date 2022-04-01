import axios from 'axios';
import React from 'react';
import { Link } from "react-router-dom";
import { Button } from "./Button";
import { Dialog, DialogClose, DialogContent, DialogDescription, DialogTitle } from "./Dialog";
import { Flex } from './Flex';
import { useAsyncEffect, useLocalStorage } from "../hooks";

const GEOIP_URL = `https://gp6lu-paaaa-aaaap-qaatq-cai.raw.ic0.app/country`;

type GeoipResponse = {iso_code?: string | null, is_in_european_union?: boolean | null, dismissed?: boolean};

const BANNED_COUNTRIES: Record<string, string> = {
    // Sanctions List:
    "BY": "Belarus",
    "BI": "Burundi",
    // Crimea and Sevastopol
    "CU": "Cuba",
    "CD": "the Democratic Republic of Congo",
    "IR": "Iran",
    "IQ": "Iraq",
    "LY": "Libya",
    "KP": "North Korea",
    "SO": "Somalia",
    "SD": "Sudan",
    "SY": "Syria",
    "VE": "Venezuela",
    "ZW": "Zimbabwe",

    // Other Exclusions:
    "US": "the United States",
    "CN": "China",
};

export function GeoipModal() {
  const [country, setCountry] = useLocalStorage<GeoipResponse|null>("country", null);
  const countryName = React.useMemo(() => country?.iso_code && BANNED_COUNTRIES[country.iso_code], [country?.iso_code]);

  useAsyncEffect(async () => {
      if (process.env.NODE_ENV !== "production") {
          setCountry(null);
          return;
      }
      if (country?.dismissed) {
          // Dialog already dismissed.
          return;
      }
      try {
          let resp = await axios.get<GeoipResponse>(GEOIP_URL)
          setCountry(resp.data);
      } catch (err) {
          setCountry(null);
          return;
      }
  }, []);

  const isOpen = React.useMemo(() => countryName && !country?.dismissed, [countryName, country?.dismissed]);

  return (
    <Dialog open={!!isOpen}>
        <DialogContent>
          <DialogTitle>Are you in {countryName}?</DialogTitle>
          <DialogDescription>
            <p>It appears you are accessing StakedICP from {countryName}.</p>

            <p>Pursuant to the <Link to="/terms-of-use">Terms of Use</Link>, citizens and residents of {countryName} are not permitted to use StakedICP's Services.</p>

            <p>If you are either of those, you must cease activity, close any positions, and withdraw all balances from the platform immediately.</p>

            <p>Persons detected using StakedICP in violation of the Terms of Service will be blocked from using the services, and may have any Fiat, Digital Tokens, funds, proceeds or other property, frozen and potentially confiscated. We may provide you a short grace period to allow for the withdrawal of property or provide you an opportunity to demonstrate to our satisfaction that you are not in violation, before blocking all services; if permitted and appropriate under applicable law and our policies. For more information, please see the <Link to="/terms-of-use">Terms of Use</Link>.</p>
          </DialogDescription>
          <Flex css={{ justifyContent: 'flex-end'}}>
            <DialogClose asChild>
              <Button variant="error" css={{marginRight: 25}} onClick={() => setCountry(country && ({...country, dismissed: true})) }>
              I am not a citizen or resident of {countryName}
              </Button>
            </DialogClose>
          </Flex>
        </DialogContent>
    </Dialog>
  );
}
