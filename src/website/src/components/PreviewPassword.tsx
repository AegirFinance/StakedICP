import React from 'react';
import { styled } from '../stitches.config';
import { Button } from "./Button";
import { Input } from "./Input";

const Wrapper = styled('form', {
  display: "flex",
  flexDirection: "column",
  justifyContent: "center",
  alignItems: "center",
  minHeight: "100%",
  width: "100%",
});

export function PreviewPassword({children}: {children?: React.ReactNode}) {
  const [password, setPassword] = React.useState("");
  const [isLoggedIn, setIsLoggedIn] = React.useState(false);

  const doLogin = React.useCallback(() => {
    if (password === "PreviewModeOn") {
    	setIsLoggedIn(true);
    }
  }, [password]);

  if (isLoggedIn || process.env.NODE_ENV === "development") {
    return (
      <>{children}</>
    );
  }

  return (
    <Wrapper onSubmit={() => {
      doLogin();
    }}>
      <Input
        type="password"
        name="password" 
        placeholder="Password"
	value={password}
        onChange={(e) => {
          setPassword(e.currentTarget.value);
        }} />
      <Button type="submit">Login</Button>
    </Wrapper>
  );
}
