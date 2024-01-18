import React from 'react';
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
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

  // @connect2ic styles
  ".img-styles": {
      height: 55,
      width: 55,
      padding: 10,
      boxSizing: "content-box",
  },

  "@media all and (max-width: 300px)": {
      ".img-styles": {
          width: "11vw",
          maxHeight: "11vw",
          height: "auto",
          padding: 0,
          paddingRight: 5,
      },

      ".button-label": {
          fontSize: "6vw",
      },
  },


  ".dialog-styles": {
    position: "fixed",
    top: 0,
    left: 0,
    width: "100%",
    height: "100%",
    zIndex: 999,
    display: "flex",
    flexDirection: "column",
    justifyContent: "center",
    alignItems: "center",
    background: "rgb(0 0 0 / 60%)",
    animation: "fade-in 0.18s",
    backdropFilter: "blur(5px)",
    cursor: "pointer",
    overflow: "auto",
    boxSizing: "border-box",
    padding: "30px",

    span: {
      fontFamily: "-apple-system, BlinkMacSystemFont, \"Arial\", \"Helvetica Neue\", sans-serif",
    },
  },

  ".dialog-container": {
    display: "grid",
    gridGap: "5px",
    padding: "10px",
    background: "#f4f4f4",
    borderRadius: "15px",
    overflow: "auto",
    gridTemplateColumns: "1fr",
    cursor: "initial",
    animation: "move-in 0.18s",
    maxWidth: "420px",
    width: "100%",
    boxSizing: "border-box",
  },

  ".dark .dialog-container": {
    background: "rgb(35 35 39)",
  },


  "@keyframes fade-in": {
    from: {
      opacity: 0,
    },
    to: {
      opacity: 1,
    },
  },

  "@keyframes move-in": {
    from: {
      transform: "translateY(5%)",
    },
    to: {
      transform: "translateY(0%)",
    },
  },

  "@-webkit-keyframes fade-out": {
    "0%": {
      opacity: 1,
    },
    "100%": {
      opacity: 0,
    },
  },

  ".button-styles": {
    background: "transparent",
    maxWidth: "100%",
    width: "100%",
    height: 75,
    padding: 10,
    border: "none",
    borderRadius: 11,
    outline: 0,
    cursor: "pointer",
    transition: "transform 0.15s",
    display: "flex",
    alignItems: "center",

    "&:hover": {
      transform: "scale(1.02)",
      fontWeight: "800!important",
      transition: "all 0.2s",
      background: "white",
    },

    "& > div": {
      display: "flex",
      padding: "0 15px",
      borderRadius: 10,
      fontWeight: 400,
      height: "100%",
      flexDirection: "column",
      alignItems: "flex-start",
      justifyContent: "center",
    }
  },

  dark: {
    ".button-styles": {
      border: "none",
      "&:hover": {
        background: "#545454",
      },
    },
    ".button-label": {
      color: "white",
    },
  },

  ".button-label": {
      marginTop: 10,
      marginBottom: 10,
      fontSize: 21,
      fontWeight: 300,
      color: "#424242",
      textAlign: "left",
  },

  ".connect-button": {
    fontSize: 18,
    background: "rgb(35 35 39)",
    color: "white",
    border: "none",
    padding: "10px 20px",
    display: "flex",
    alignItems: "center",
    borderRadius: 40,
    cursor: "pointer",

    "&:hover": {
      transform: "scale(1.03)",
      transition: "all 0.4s",
    },
  },
});

export default function App() {
  globalStyles();

  // const maintenance = React.useMemo(() => !(new URLSearchParams(location.search).get("preview")), [location.search]);
  const maintenance = false;

  return (
    <div>
      <WalletProvider>
        {maintenance ? (
          <Maintenance />
        ) : (
          <BrowserRouter>
            <GeoipModal />
            <Routes>
              <Route path="/" element={<Pages.Stake />} />
              <Route path="/privacy-policy" element={<Pages.PrivacyPolicy />} />
              <Route path="/rewards" element={<Navigate to="/referrals" />} />
              <Route path="/referrals" element={<Pages.Referrals />} />
              <Route path="/terms-of-use" element={<Pages.TermsOfUse />} />
              <Route path="*" element={<Pages.FourOhFour />} />
            </Routes>
          </BrowserRouter>
        )}
      </WalletProvider>
    </div>
  );
}
