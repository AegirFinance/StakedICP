import { styled } from '../stitches.config';

export function Maintenance() {
    return (
        <Wrapper>
            <h1>Under Maintenance</h1>
            <p>This page is under maintenance and will be back soon.</p>
        </Wrapper>
    );
}

const Wrapper = styled('div', {
  backgroundColor: '$slate1',
  display: "flex",
  flexDirection: "column",
  alignItems: "stretch",
  padding: "$4",
  borderRadius: '$1',
  minWidth: "300px",
  boxShadow: '$large',
  '& > * + *': {
    marginTop: '$2',
  },
});
