import React from "react";
import { keyframes, styled } from "../stitches.config";

// Copy some text value to the clipboard on click.
export function CopyOnClick({
  children,
  disabled=false,
  value,
}: {
  children?: React.ReactNode;
  disabled?: boolean;
  value: string;
}) {
  const [active, setActive] = React.useState(false);
  return (
    <Wrapper
      onClick={e => {
        e.preventDefault();
        if (disabled) return;
        copyToClipboard(value);
        setActive(true);
      }}
    >
      <Children>{children || value}</Children>
      <Message
        className={active ? "fade" : ""}
        onAnimationEnd={() => setActive(false)}
      >
        Copied!
      </Message>
    </Wrapper>
  );
}

function copyToClipboard(value: string) {
  const textField = document.createElement("textarea");
  textField.innerText = value;
  document.body.appendChild(textField);
  textField.select();
  document.execCommand("copy");
  textField.remove();
}

const fadeOut = keyframes({
  "0%": { opacity: 0, },
  "10%": { opacity: 1, },
  "100%": { opacity: 0, },
});

const Children = styled('span', {
  marginRight: "0.5em",
});

const Message = styled('span', {
  opacity: "0",
  fontWeight: "normal",
  "&.fade": {
    animation: `${fadeOut} 1s linear`,
  }
});

const Wrapper = styled('span', {
  display: "inline-flex",
  flexDirection: "row",
  flexWrap: "nowrap",
  justifyContent: "flex-start",
  alignItems: "center",
  cursor: "pointer",
});
