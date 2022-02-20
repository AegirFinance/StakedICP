import { styled } from '../stitches.config';

export const DataTable = styled('div', {
  display: "flex",
  flexDirection: "column",
  alignItems: "stretch",

  marginBottom: '$1',
  '& > *': {
    marginTop: '$1',
  },
});

export const DataTableRow = styled('div', {
  display: "flex",
  flexDirection: "row",
  alignItems: "baseline",
  justifyContent: "space-between",
});

export const DataTableLabel = styled('span', {
  color: '$slate11',
});

export const DataTableValue = styled('span', {});

