import React from 'react';
import { Link } from "react-router-dom";
import { Flex, TestnetBanner } from '.';

export function Layout({children}: {children?: React.ReactNode}) {
  return (
    <>
      <TestnetBanner />
      {children}
      <Footer />
    </>
  );
}

function Footer() {
  return (
    <Flex css={{flexDirection:"row", flexWrap: "wrap", justifyContent: "center"}}>
      <Flex css={{flexDirection:"row", flexWrap: "wrap", justifyContent: "space-around", maxWidth: 1024, padding: "$4 0", '& > *': { margin: '$4'}}}>
        <Link to="/terms-of-use" title="Terms of Use">Terms of Use</Link>
        <Link to="/privacy-policy" title="Privacy Policy">Privacy Policy</Link>
      </Flex>
    </Flex>
  );
}
