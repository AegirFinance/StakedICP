import React from "react";
import { styled } from "../stitches.config";

export type InputParams = Parameters<typeof Element>[0] & {
    prefix?: React.ReactNode;
};

export function Input({prefix, ...p}: InputParams) {
    return (
        <Wrapper>
            {prefix && (
              <Prefix>{prefix}</Prefix>  
            )}
            <Element {...p} hasPrefix={!!prefix} />
        </Wrapper>
    );
}

const Wrapper = styled('label', {
    all: 'unset',
    color: '$slate12',
    borderStyle: 'solid',
    borderColor: '$slate7',
    borderRadius: '$1',
    borderWidth: '$1',
    background: '$slate1',
    display: 'flex',
    flexDirection: 'row',
    justifyContent: 'stretch',
    alignItems: 'stretch',
    '&:hover': {
        borderColor: '$slate8',
    },
    '&:active': {
        borderColor: '$slate8',
    },
});

const Prefix = styled('div', {
    all: 'unset',
    padding: '$2 $3',
    grow: 0,
});

const Element = styled('input', {
    all: 'unset',
    padding: '$2 $3',
    width: '100%',
    variants: {
        hasPrefix: {
            true: {
                textAlign: 'right',
            },
        },
    },
});
