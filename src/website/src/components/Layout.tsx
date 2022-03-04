import React from 'react';
import { Link } from "react-router-dom";
import { Flex, TestnetBanner } from '.';

export function Layout({children}: {children?: React.ReactNode}) {
  return (
    <>
      <TestnetBanner />
      {children}
    </>
  );
}
