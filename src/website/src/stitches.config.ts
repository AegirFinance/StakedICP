import {
  blue,
  slate,
  red,
  green,
  yellow,
  blueDark,
  slateDark,
  redDark,
  greenDark,
  yellowDark,
} from '@radix-ui/colors';
import { createStitches } from "@stitches/react";

export const {
  styled,
  css,
  globalCss,
  keyframes,
  getCssText,
  theme,
  createTheme,
  config,
} = createStitches({
  theme: {
    colors: {
      ...blue,
      ...slate,
      ...red,
      ...green,
      ...yellow,
    },
    space: {
      1: '5px',
      2: '10px',
      3: '15px',
      4: '20px',
    },
    fontSizes: {
      1: '12px',
      2: '13px',
      3: '15px',
    },
    fonts: {
      manrope: 'Manrope, apple-system, sans-serif',
      untitled: 'Untitled Sans, apple-system, sans-serif',
      mono: 'Söhne Mono, menlo, monospace',
    },
    fontWeights: {},
    lineHeights: {},
    letterSpacings: {},
    sizes: {},
    borderWidths: {
      0: '0px',
      1: '1px',
    },
    borderStyles: {},
    radii: {
      1: '4px',
    },
    shadows: {},
    zIndices: {},
    transitions: {},
  },
});

// TODO: Use this based on system preference
export const darkTheme = createTheme({
  colors: {
    ...blueDark,
    ...slateDark,
    ...redDark,
    ...greenDark,
    ...yellowDark,
  },
  space: {},
  fonts: {},
});
