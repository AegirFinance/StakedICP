import axios from 'axios';
import React from 'react';
import { Button } from "./Button";
import { Dialog, DialogClose, DialogContent, DialogDescription, DialogTitle } from "./Dialog";
import { Flex } from './Flex';
import { useAsyncEffect, useLocalStorage } from "../hooks";

const GEOIP_URL = `https://geoip.stakedicp.com`;

type GeoipResponse = {iso_code?: string | null, is_in_european_union?: boolean | null};

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
  const [countryName, setCountryName] = useLocalStorage<string|null>("country", null);

  useAsyncEffect(async () => {
      if (process.env.NODE_ENV !== "production") {
          setCountryName(null);
          return;
      }
      if (!!countryName) {
          // Dialog already dismissed.
          return;
      }
      try {
          let resp = await axios.get<GeoipResponse>(GEOIP_URL)
          if (!resp.data.iso_code) {
              setCountryName(null);
              return;
          }
          setCountryName(BANNED_COUNTRIES[resp.data.iso_code] ?? null);
      } catch (err) {
          setCountryName(null);
          return;
      }
  }, []);

  return (
    <Dialog open={!!countryName}>
        <DialogContent>
          <DialogTitle>Warning</DialogTitle>
          <DialogDescription>
            StakedICP is unable to provide services to users in {countryName}.
          </DialogDescription>
          <Flex css={{ justifyContent: 'flex-end'}}>
            <DialogClose asChild>
              <Button variant="error" css={{marginRight: 25}} onClick={() => setCountryName(null)}>
              Ok
              </Button>
            </DialogClose>
          </Flex>
        </DialogContent>
    </Dialog>
  );
}
