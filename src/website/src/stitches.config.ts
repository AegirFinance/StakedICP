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
      5: '25px',
      6: '30px',
      7: '35px',
      8: '40px',
      9: '45px',
      10: '50px',
      11: '55px',
      12: '60px',
      13: '65px',
      14: '70px',
      15: '75px',
      16: '80px',
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
    shadows: {
      card: '0px 1px 1px rgba(12, 25, 39, .08), 0px 1px 3px rgba(12, 25, 39, .14)',
      input: '0px 1px 0px rgba(255, 255, 255, .2), inset 0px 0px 1px rgba(12, 25, 39, .24), inset 0px 1px 0px rgba(12, 25, 39, .04)',
      inputFocus: '0px 0px 5px rgba(49, 242, 204, .4), 0px 0px 1px 1px rgba(20, 204, 166, .4)',
      darkInput: '0px 1px 1px 0 rgba(12, 25, 39, .8), 0px 1px 3px rgba(12, 25, 39, .4), inset 0px 1px 1px rgba(255, 255, 255, .04)',
      darkInputText: '0px 1px 0px rgba(12, 25, 39, .2)',
      medium: '0 50px 60px rgb(12 25 39 / 10%), 0 16px 20px rgb(12 25 39 / 6%), 0 6px 8px rgb(12 25 39 / 5%)',
      large: '0 192px 136px rgba(26,43,59,0.23), 0 70px 50px rgba(26,43,59,0.16), 0 34px 24px rgba(26,43,59,0.13), 0 17px 12px rgba(26,43,59,0.1), 0 7px 5px rgba(26,43,59,0.07)',
    },
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
