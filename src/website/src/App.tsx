import * as deposits from "../../declarations/deposits";
import * as nnsLedger from "../../declarations/nns-ledger";
import * as token from "../../declarations/token";
import React from 'react';
import { BrowserRouter, Route, Routes } from "react-router-dom";
import { GeoipModal, Maintenance } from './components';
import { globalCss } from './stitches.config';
import { Provider as WalletProvider } from "./wallet";
import * as Pages from "./pages";

const globalStyles = globalCss({
  ':root': {
      webkitFontSmoothing: 'antialiased',
  },
  '@font-face': {
    fontFamily: 'Manrope',
    src: "url('https://fonts.googleapis.com/css2?family=Manrope:wght@200;400;800&display=swap')",
  },
  '*': {
    margin: 0,
    padding: 0,
    fontFamily: '$manrope',
    color: '$slate12',

  },
  'body': {
    backgroundColor: '$slate1',
  },
});

export default function App() {
  globalStyles();

  // const maintenance = React.useMemo(() => !(new URLSearchParams(location.search).get("preview")), [location.search]);
  const maintenance = false;

  return (
    <div>
      <WalletProvider whitelist={[deposits.canisterId, nnsLedger.canisterId, token.canisterId].filter(x => !!x) as string[]} host={process.env.NETWORK} dev={process.env.NODE_ENV === "development"}>
        {maintenance ? (
          <Maintenance />
        ) : (
          <BrowserRouter>
            <GeoipModal />
            <Routes>
              <Route path="/" element={<Pages.Stake />} />
              <Route path="/privacy-policy" element={<Pages.PrivacyPolicy />} />
              <Route path="/rewards" element={<Pages.Rewards />} />
              <Route path="/terms-of-use" element={<Pages.TermsOfUse />} />
              <Route path="*" element={<Pages.FourOhFour />} />
            </Routes>
          </BrowserRouter>
        )}
      </WalletProvider>
    </div>
  );
}
