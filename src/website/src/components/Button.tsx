import React from "react";
import { styled } from "../stitches.config";

export const ButtonStyles = {
  backgroundColor: '$blue9',
  color: '$slate1',
  borderRadius: '$1',
  borderWidth: '$0',
  textShadow: '0px 1px 0px rgb(255 255 255 / 20%)',
  boxShadow: '$card',
  padding: '$2 $3',
  '&:hover': {
    backgroundColor: '$blue10',
    cursor: 'pointer',
  },
  '&[disabled]': {
    backgroundColor: '$blue3',
    color: '$slate11',
    cursor: 'default',
  },

  variants: {
    variant: {
      cancel: {
        backgroundColor: '$slate3',
        color: '$slate12',
        '&:hover': {
          backgroundColor: '$blue3',
        },
      },

      error: {
        backgroundColor: '$slate3',
        color: '$red12',
        '&:hover': {
          backgroundColor: '$red3',
          color: '$red12',
        },
      },
    },
  },
};

export const Button = styled('button', ButtonStyles);
