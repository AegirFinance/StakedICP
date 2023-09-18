import * as SliderPrimitive from '@radix-ui/react-slider';
import { styled } from '../../stitches.config';

export interface SliderParams {
  disabled?: boolean;
  value?: number[];
  min?: number;
  max?: number;
  step?: number;
  onValueChange?: (value: number[]) => void;
  "aria-label"?: string;
}

export function Slider({
  disabled,
  ...params
}: SliderParams) {
  return (
    <StyledSlider disabled={disabled} {...params}>
      <StyledTrack>
        <StyledRange />
      </StyledTrack>
      <StyledThumb disabled={disabled} />
    </StyledSlider>
  );
}

const StyledSlider = styled(SliderPrimitive.Root, {
  position: 'relative',
  display: 'flex',
  alignItems: 'center',
  userSelect: 'none',
  touchAction: 'none',

  '&[data-orientation="horizontal"]': {
    height: 20,
  },

  '&[data-orientation="vertical"]': {
    flexDirection: 'column',
    width: 20,
    height: 100,
  },
});

const StyledTrack = styled(SliderPrimitive.Track, {
  backgroundColor: '$slate10',
  position: 'relative',
  flexGrow: 1,
  borderRadius: '9999px',

  '&[data-orientation="horizontal"]': { height: 3 },
  '&[data-orientation="vertical"]': { width: 3 },
});

const StyledRange = styled(SliderPrimitive.Range, {
  position: 'absolute',
  backgroundColor: '$slate10',
  borderRadius: '9999px',
  height: '100%',
});

const StyledThumb = styled(SliderPrimitive.Thumb, {
  all: 'unset',
  display: 'block',
  width: 20,
  height: 20,
  backgroundColor: '$blue9',
  boxShadow: `0 2px 10px $slate7`,
  borderRadius: 10,
  variants: {
    disabled: {
      true: {
        backgroundColor: '$slate10',
        cursor: 'default',
      },
      false: {
        '&:hover': { backgroundColor: '$blue10', cursor: 'pointer' },
        '&:focus': { boxShadow: `0 0 0 5px $slate8` },
      },
    },
  },
});

