import React, { SVGProps } from 'react';
import { Link } from "react-router-dom";
import * as token from "../../../declarations/token";
import { styled } from '../stitches.config';
import { ConnectButton, ConnectDialog, useBalance, useWallet } from "../wallet";
import { ActivityIndicator } from "./ActivityIndicator"
import { Button } from "./Button";
import * as format from "../format";

// TODO: do some media queries here
const Wrapper = styled('header', {
  display: "flex",
  flexDirection: "row",
  flexWrap: "wrap",
  alignItems: "center",
  padding: '$2 $4',
});

const Logo = (props: SVGProps<SVGSVGElement>) => (
  <svg
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 340 87"
    aria-label="Staked ICP"
    {...props}
  >
    <path
      d="M11.214 68.588c-2.562 0-4.69-.532-6.384-1.596-1.694-1.078-2.744-2.562-3.15-4.452l1.806-.336c.378 1.4 1.26 2.52 2.646 3.36 1.4.84 3.108 1.26 5.124 1.26 2.058 0 3.689-.441 4.893-1.323 1.218-.882 1.827-2.079 1.827-3.591 0-.826-.182-1.498-.546-2.016-.364-.532-1.078-1.015-2.142-1.449-1.05-.434-2.604-.931-4.662-1.491-2.156-.588-3.836-1.155-5.04-1.701-1.19-.56-2.03-1.183-2.52-1.869-.476-.7-.714-1.554-.714-2.562 0-1.204.357-2.268 1.071-3.192.714-.924 1.701-1.645 2.961-2.163 1.26-.518 2.716-.777 4.368-.777 1.666 0 3.164.28 4.494.84 1.344.546 2.422 1.316 3.234 2.31a6.078 6.078 0 0 1 1.428 3.402l-1.806.336c-.266-1.582-1.078-2.828-2.436-3.738-1.344-.924-3.024-1.386-5.04-1.386-1.89-.028-3.437.357-4.641 1.155-1.19.798-1.785 1.841-1.785 3.129 0 .714.203 1.33.609 1.848.406.504 1.113.966 2.121 1.386 1.008.42 2.408.854 4.2 1.302 2.268.574 4.032 1.155 5.292 1.743 1.274.588 2.163 1.274 2.667 2.058.518.784.777 1.757.777 2.919 0 2.058-.77 3.675-2.31 4.851-1.54 1.162-3.654 1.743-6.342 1.743ZM51.352 68a11.945 11.945 0 0 1-3.36.273c-1.106-.056-2.093-.315-2.96-.777-.869-.476-1.52-1.19-1.954-2.142a6.257 6.257 0 0 1-.567-2.247 48.705 48.705 0 0 1-.063-2.625V39.02h1.764v21.462c0 .98.007 1.771.021 2.373.028.602.175 1.169.441 1.701.504 1.008 1.302 1.631 2.394 1.869 1.092.224 2.52.189 4.284-.105V68ZM37.114 47.084V45.32h14.238v1.764H37.114ZM77.262 68.63c-1.764 0-3.227-.308-4.389-.924-1.162-.616-2.03-1.428-2.604-2.436a6.51 6.51 0 0 1-.86-3.276c0-1.33.286-2.429.86-3.297a6.284 6.284 0 0 1 2.29-2.079 11.14 11.14 0 0 1 3.023-1.092 61.845 61.845 0 0 1 4.221-.693c1.512-.21 2.905-.385 4.18-.525 1.273-.14 2.225-.252 2.855-.336l-.63.42c.07-2.674-.42-4.662-1.47-5.964-1.036-1.316-2.87-1.974-5.502-1.974-1.904 0-3.437.427-4.599 1.281-1.148.84-1.953 2.135-2.415 3.885l-1.932-.504c.504-2.1 1.533-3.696 3.087-4.788 1.568-1.092 3.55-1.638 5.943-1.638 2.1 0 3.85.427 5.25 1.281 1.4.854 2.352 2.009 2.856 3.465.196.56.336 1.239.42 2.037.084.798.126 1.575.126 2.331V68h-1.638v-6.216l.84.042c-.602 2.156-1.799 3.829-3.59 5.019-1.793 1.19-3.9 1.785-6.322 1.785Zm-.084-1.764c1.638 0 3.08-.294 4.326-.882 1.26-.588 2.275-1.435 3.045-2.541.784-1.12 1.281-2.457 1.491-4.011.112-.784.168-1.624.168-2.52V54.98l.924.714-3.087.294a86.941 86.941 0 0 0-4.137.462 33.48 33.48 0 0 0-3.948.714c-.686.168-1.393.434-2.12.798a5.273 5.273 0 0 0-1.849 1.533c-.49.658-.735 1.505-.735 2.541 0 .728.182 1.463.546 2.205.364.742.973 1.365 1.827 1.869.868.504 2.051.756 3.55.756ZM108.552 68V37.76h1.764v18.48l11.34-10.92h2.646l-11.844 11.34L126.108 68h-3.024l-12.768-10.92V68h-1.764Zm43.47.63c-2.142 0-3.99-.483-5.544-1.449-1.54-.966-2.73-2.345-3.57-4.137-.84-1.792-1.26-3.92-1.26-6.384 0-2.478.413-4.613 1.239-6.405.84-1.792 2.03-3.164 3.57-4.116 1.554-.966 3.409-1.449 5.565-1.449 2.17 0 4.025.49 5.565 1.47s2.716 2.401 3.528 4.263c.826 1.862 1.239 4.109 1.239 6.741h-1.89v-.588c-.084-3.262-.854-5.761-2.31-7.497-1.442-1.75-3.486-2.625-6.132-2.625-2.688 0-4.774.896-6.258 2.688-1.484 1.778-2.226 4.284-2.226 7.518s.742 5.747 2.226 7.539c1.484 1.778 3.57 2.667 6.258 2.667 1.876 0 3.521-.441 4.935-1.323 1.414-.882 2.541-2.149 3.381-3.801l1.47.84c-.924 1.932-2.233 3.423-3.927 4.473-1.694 1.05-3.647 1.575-5.859 1.575Zm-9.24-11.466V55.4h18.48v1.764h-18.48Zm47.932 11.466c-2.142 0-3.948-.525-5.418-1.575-1.456-1.064-2.562-2.499-3.318-4.305-.756-1.82-1.134-3.864-1.134-6.132 0-2.226.371-4.242 1.113-6.048s1.82-3.234 3.234-4.284c1.428-1.064 3.157-1.596 5.187-1.596 2.114 0 3.892.518 5.334 1.554 1.456 1.022 2.555 2.436 3.297 4.242.742 1.792 1.113 3.836 1.113 6.132 0 2.254-.371 4.291-1.113 6.111-.728 1.806-1.792 3.241-3.192 4.305-1.4 1.064-3.101 1.596-5.103 1.596Zm0-1.764c1.778 0 3.262-.448 4.452-1.344 1.204-.896 2.107-2.114 2.709-3.654.602-1.554.903-3.304.903-5.25 0-1.974-.308-3.724-.924-5.25-.602-1.54-1.505-2.744-2.709-3.612-1.19-.868-2.667-1.302-4.431-1.302-1.806 0-3.304.448-4.494 1.344-1.176.882-2.051 2.093-2.625 3.633-.574 1.526-.861 3.255-.861 5.187 0 1.946.301 3.696.903 5.25.602 1.54 1.491 2.758 2.667 3.654 1.19.896 2.66 1.344 4.41 1.344ZM198.778 68V50.15h-.126V37.76h1.764V68h-1.638Zm24.826 0V21.92h8.704V68h-8.704Zm44.473.96c-4.608 0-8.586-1.003-11.936-3.008-3.328-2.005-5.898-4.81-7.712-8.416-1.792-3.605-2.688-7.797-2.688-12.576 0-4.779.896-8.97 2.688-12.576 1.814-3.605 4.384-6.41 7.712-8.416 3.35-2.005 7.328-3.008 11.936-3.008 5.291 0 9.728 1.312 13.312 3.936 3.606 2.624 6.144 6.176 7.616 10.656l-8.768 2.432c-.853-2.795-2.293-4.96-4.32-6.496-2.026-1.557-4.64-2.336-7.84-2.336-2.922 0-5.365.65-7.328 1.952-1.941 1.301-3.402 3.136-4.384 5.504-.981 2.368-1.472 5.152-1.472 8.352s.491 5.984 1.472 8.352c.982 2.368 2.443 4.203 4.384 5.504 1.963 1.301 4.406 1.952 7.328 1.952 3.2 0 5.814-.779 7.84-2.336 2.027-1.557 3.467-3.723 4.32-6.496l8.768 2.432c-1.472 4.48-4.01 8.032-7.616 10.656-3.584 2.624-8.021 3.936-13.312 3.936Zm34.374-.96V21.92h19.456c.448 0 1.045.021 1.792.064.768.021 1.451.085 2.048.192 2.752.427 5.003 1.333 6.752 2.72a12.244 12.244 0 0 1 3.904 5.248c.832 2.09 1.248 4.427 1.248 7.008 0 2.581-.427 4.928-1.28 7.04a12.276 12.276 0 0 1-3.904 5.216c-1.749 1.387-3.989 2.293-6.72 2.72-.597.085-1.28.15-2.048.192-.768.043-1.365.064-1.792.064h-10.752V68h-8.704Zm8.704-23.744h10.368c.448 0 .939-.021 1.472-.064a7.556 7.556 0 0 0 1.472-.256c1.173-.32 2.08-.853 2.72-1.6a6.393 6.393 0 0 0 1.312-2.528c.256-.939.384-1.824.384-2.656 0-.832-.128-1.707-.384-2.624A6.12 6.12 0 0 0 327.187 32c-.64-.768-1.547-1.312-2.72-1.632a7.556 7.556 0 0 0-1.472-.256 18.541 18.541 0 0 0-1.472-.064h-10.368v14.208Z"
      fill="#000"
    />
  </svg>
)

const Balance = styled('span', {
  display: "flex",
  flexDirection: "row",
  flexWrap: "no-wrap",
  margin: "1rem",
});

export function Header() {
  const [wallet] = useWallet();
  const [balance, _] = useBalance("token");
  const formatted = wallet?.principal && balance?.formatted;

  return (
    <Wrapper>
      <Link to="/" style={{marginRight: "auto", display: "flex", alignItems: "center"}}>
        <img height="28" width="28" style={{marginRight: "0.75rem"}} src="./logo192.png" />
        <Logo style={{height: "2.5rem"}} />
      </Link>

      {wallet && (
        <Balance>{formatted ? formatted : <ActivityIndicator css={{marginRight: "1ch"}} /> } stICP</Balance>
      )}
      <Link to="/referrals" style={{marginRight: "0.75rem"}}>
        <Button variant="cancel">Referrals</Button>
      </Link>
      <ConnectButton />
      <ConnectDialog />
    </Wrapper>
  );
}
