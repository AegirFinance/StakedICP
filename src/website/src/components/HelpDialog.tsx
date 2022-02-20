import { QuestionIcon } from '@primer/octicons-react'
import * as Popover from '@radix-ui/react-popover';
import React from 'react';
import { styled } from '../stitches.config';

export type HelpDialogOptions = {
  children?: React.ReactNode;
  'aria-label'?: string;
};

export function HelpDialog(options: HelpDialogOptions) {
  return (
    <Popover.Root>
      <StyledTrigger><QuestionIcon aria-label={options['aria-label']} fill="currentColor" /></StyledTrigger>
      <StyledContent>
        {options.children}
        <StyledArrow />
      </StyledContent>
    </Popover.Root>
  );
}

const StyledTrigger = styled(Popover.Trigger, {
  display: 'inline-block',
  backgroundColor: 'transparent',
  border: 0,

});

const StyledContent = styled(Popover.Content, {
  borderRadius: '$1',
  padding: '$3',
  backgroundColor: '$slate11',
  color: '$slate2',
  maxWidth: '240px',
  '& > p': {
    color: '$slate2',
  },
});

const StyledArrow = styled(Popover.Arrow, {
  fill: '$slate11',
});
