import React from 'react';
import { idlFactory, canisterId } from '../../../declarations/token';
import { Token } from "../../../declarations/token/token.did.d.js";
import { getBackendActor }  from '../agent';
import * as format from "../format";
import { useAsyncEffect } from "../hooks";
import { styled } from '../stitches.config';
import { ActivityIndicator } from "./ActivityIndicator";
import { DataTable, DataTableRow, DataTableLabel, DataTableValue } from './DataTable';

const Wrapper = styled('div', {
  backgroundColor: '$slate3',
  display: "flex",
  flexDirection: "column",
  alignItems: "stretch",
  padding: "$1",
  borderRadius: '$1',
  minWidth: "300px",
});

export function Statistics() {
  const [stats, setStats] = React.useState<any|null>(null);

  useAsyncEffect(async () => {
    // TODO: Have to use dfinity agent here, as we dont need the user's plug wallet connected.
    console.debug("starting");
    if (!canisterId) throw new Error("Canister not deployed");
    const contract = await getBackendActor<Token>({canisterId, interfaceFactory: idlFactory});
    console.debug("contract:", {contract});

    const [meta, stakers] = await Promise.all([
      contract.getMetadata(),
      contract.getHoldersSize(),
    ]);
    console.debug({meta, stakers});
    setStats({
      ...meta,
      stakers,
    });
  }, []);

  return (
    <Wrapper>
      <DataTable>
        {/* TODO: Add Estimated APR here */}
        <DataTableRow>
          <DataTableLabel>Total Supply</DataTableLabel>
          <DataTableValue>
            {stats !== null
              ? `${format.units(stats.totalSupply || 0, 8)} stICP`
              : <ActivityIndicator />}
          </DataTableValue>
        </DataTableRow>
        <DataTableRow>
          <DataTableLabel>Stakers</DataTableLabel>
          <DataTableValue>
            {stats !== null
              ? `${stats.stakers || 0}`
              : <ActivityIndicator />}
          </DataTableValue>
        </DataTableRow>
      </DataTable>
    </Wrapper>
  );
}
