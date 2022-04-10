import React from 'react';
import { Flex, Header, Layout } from '../components';
import { styled } from '../stitches.config';

const Title = styled('h1', {
  margin: '$2 0',
});

export function FourOhFour() {
  return (
    <Layout>
      <Header />
      <Flex css={{flexDirection:"column", alignItems: "center"}}>
        <Flex css={{flexDirection:"column", maxWidth: 1024, padding: "$2"}}>
          <Title>404 - Page Not Found</Title>
        </Flex>
      </Flex>
    </Layout>
  );
}
