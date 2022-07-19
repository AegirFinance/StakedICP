import React from "react";

export function STICPLogo(p: Omit<React.DetailedHTMLProps<React.ImgHTMLAttributes<HTMLImageElement>, HTMLImageElement>, "src">) {
  return (
    <img
      alt="stICP"
      {...p}
      src="/logo.png"
    />
  );
}
