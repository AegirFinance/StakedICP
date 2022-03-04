import * as Accordion from '@radix-ui/react-accordion';
import { ChevronDownIcon, GitHubLogoIcon, TwitterLogoIcon } from '@radix-ui/react-icons';
import * as deposits from "../../declarations/deposits";
import * as token from "../../declarations/token";
import React from 'react';
import { BrowserRouter, Link, Route, Routes } from "react-router-dom";
import { Flex, PreviewPassword, TestnetBanner } from './components';
import { globalCss } from './stitches.config';
import { Provider as WalletProvider } from "./wallet";
import * as Pages from "./pages";

const globalStyles = globalCss({
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
  }
});

export default function App() {
  globalStyles();

  return (
    <div>
      <PreviewPassword>
        <WalletProvider autoConnect whitelist={[deposits.canisterId, token.canisterId].filter(x => !!x) as string[]} host={process.env.NETWORK}>
          <BrowserRouter>
            <Routes>
              <Route path="/" element={<Pages.Deposit />} />
              <Route path="/terms-of-use" element={<Pages.TermsOfUse />} />
              <Route path="/privacy-policy" element={<Pages.PrivacyPolicy />} />
            </Routes>
          </BrowserRouter>
        </WalletProvider>
      </PreviewPassword>
    </div>
  );
}
