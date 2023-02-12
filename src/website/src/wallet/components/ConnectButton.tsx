import React, { SVGProps } from "react";
import {
  Button,
  Dialog,
  DialogContent,
  DialogDescription,
  DialogTitle,
  DialogTrigger,
  Flex,
} from "../../components";
import * as format from "../../format";
import { styled } from '../../stitches.config';
import { useAccount, useConnect } from "../hooks";
import { useContext } from "../context";


export function ConnectButton({
  title = "Connect Wallet",
}: {
  title?: string,
}) {
  const {state} = useContext();
  const [{ data: account }, disconnect] = useAccount();
  const [_, connect] = useConnect();

  const switchAndConnect = (name: string) => {
    let connector = (state.connectors ?? []).find(c => c.name === name);
    if (!connector) {
      throw new Error(`${name} not configured`);
    }
    connect(connector);
  };

  if (account?.principal) {
    return (
      <Flex css={{'> * + *': {
        marginLeft: '0.75rem',
      }}}>
        <Button disabled>
          {format.shortPrincipal(account?.principal)}
        </Button>

        <Button variant="error" onClick={() => {
          disconnect()
        }}>
          Disconnect
        </Button>
      </Flex>
    );
  }

  return (
    <Dialog>
      <DialogTrigger asChild>
        <Button>{title}</Button>
      </DialogTrigger>
      <DialogContent>
        <DialogTitle>Connect your wallet</DialogTitle>
        <Flex css={{
          flexDirection: "row",
          justifyContent: "center",
          alignItems: "stretch",
          flexWrap: 'wrap',
          paddingTop: '1rem',
          '> *': {
            marginLeft: '0.75rem',
            marginRight: '0.75rem',
          },
          button: {
            height: '144px',
          },
        }}>
          <WalletButton onClick={() => { switchAndConnect("Bitfinity") }}>
            <BitfinityLogo />
            <h3>Bitfinity Wallet</h3>
          </WalletButton>
          <Flex css={{
            flexDirection: "column",
            alignItems: "stretch",
            h5: {
              marginTop: '0.5rem',
            }
          }}>
            <WalletButton onClick={() => { switchAndConnect("Plug") }}>
              <PlugLogo />
              <h3>Plug Wallet</h3>
            </WalletButton>
            <h5>(Deprecated)</h5>
            <h6>Will be removed <time dateTime="2023-04-12T12:00Z">April 16, 2023</time>.</h6>
          </Flex>
        </Flex>
      </DialogContent>
    </Dialog>
  );
}

const WalletButton = styled('button', {
  display: 'flex',
  flexDirection: 'column',
  justifyContent: 'center',
  alignItems: 'center',
  border: 'none',
  padding: '1rem',
  borderRadius: '10px',
  cursor: 'pointer',
  transition: 'transform 0.3s',

  '> *': {
    marginTop: '0.5rem',
    marginBottom: '0.5rem',
  },

  '&:hover': {
    transform: 'scale(1.03)',
  },
});

const PlugLogo = (props: SVGProps<SVGSVGElement>) => (
  <svg
    width={18}
    height={27}
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    {...props}
  >
    <g clipPath="url(#pluga)">
      <path
        d="M3.366.414c0-.229.179-.414.4-.414h1.826c.22 0 .4.185.4.414v6.248H3.365V.414ZM11.949.414c0-.229.179-.414.4-.414h1.826c.22 0 .4.185.4.414v6.248h-2.626V.414Z"
        fill="#031514"
      />
      <path
        d="M0 7.753c0-.6.47-1.088 1.052-1.088h15.89c.581 0 1.052.487 1.052 1.088v5.42c0 5.143-4.028 9.311-8.997 9.311S0 18.316 0 13.174v-5.42Z"
        fill="url(#plugb)"
      />
      <path
        d="M5.993 21.695H12v.776c0 1.126-.883 2.04-1.972 2.04H7.965c-1.089 0-1.972-.914-1.972-2.04v-.776Z"
        fill="url(#plugc)"
      />
      <path
        d="M6.966 24.184h4.062v1.456c0 .751-.589 1.36-1.315 1.36H8.281c-.726 0-1.315-.609-1.315-1.36v-1.456Z"
        fill="url(#plugd)"
      />
      <path
        fillRule="evenodd"
        clipRule="evenodd"
        d="M17.281 16.81c-1.386-5.236-6.017-9.084-11.517-9.084-2.09 0-4.055.556-5.764 1.532v3.915c0 4.053 2.501 7.5 5.994 8.78v.518c0 .749.39 1.404.972 1.759v1.41c0 .75.589 1.36 1.315 1.36h1.432c.726 0 1.315-.61 1.315-1.36v-1.41c.582-.355.972-1.01.972-1.76v-.517c2.38-.872 4.3-2.751 5.281-5.142Z"
        fill="url(#pluge)"
      />
      <path
        fillRule="evenodd"
        clipRule="evenodd"
        d="M15.13 19.985c-.44-5.246-4.695-9.362-9.88-9.362-1.927 0-3.727.57-5.25 1.555v.996c0 4.052 2.501 7.5 5.994 8.779v.518c0 .75.39 1.404.972 1.759v1.41c0 .751.589 1.36 1.315 1.36h1.432c.726 0 1.315-.609 1.315-1.36v-1.41c.582-.355.972-1.01.972-1.76v-.517a8.946 8.946 0 0 0 3.13-1.968Z"
        fill="url(#plugf)"
      />
      <path
        fillRule="evenodd"
        clipRule="evenodd"
        d="M12.01 21.951c-.187-4.276-3.595-7.682-7.773-7.682a7.548 7.548 0 0 0-3.974 1.128c.723 3.055 2.903 5.518 5.735 6.556v.518c0 .75.39 1.404.973 1.759v1.41c0 .751.588 1.36 1.314 1.36h1.433c.726 0 1.314-.609 1.314-1.36v-1.41c.582-.355.973-1.01.973-1.76v-.517l.005-.002Z"
        fill="url(#plugg)"
      />
    </g>
    <defs>
      <linearGradient
        id="plugb"
        x1={12.007}
        y1={12.527}
        x2={18.702}
        y2={6.051}
        gradientUnits="userSpaceOnUse"
      >
        <stop stopColor="#46FF47" />
        <stop offset={1} stopColor="#9CFF9D" />
      </linearGradient>
      <linearGradient
        id="plugc"
        x1={12.007}
        y1={12.527}
        x2={18.702}
        y2={6.051}
        gradientUnits="userSpaceOnUse"
      >
        <stop stopColor="#46FF47" />
        <stop offset={1} stopColor="#9CFF9D" />
      </linearGradient>
      <linearGradient
        id="plubd"
        x1={12.007}
        y1={12.528}
        x2={18.702}
        y2={6.051}
        gradientUnits="userSpaceOnUse"
      >
        <stop stopColor="#46FF47" />
        <stop offset={1} stopColor="#9CFF9D" />
      </linearGradient>
      <linearGradient
        id="pluge"
        x1={10.443}
        y1={13.813}
        x2={13.771}
        y2={9.543}
        gradientUnits="userSpaceOnUse"
      >
        <stop stopColor="#10D9ED" />
        <stop offset={1} stopColor="#10D9ED" stopOpacity={0.3} />
      </linearGradient>
      <linearGradient
        id="plugf"
        x1={9.733}
        y1={15.37}
        x2={12.014}
        y2={11.122}
        gradientUnits="userSpaceOnUse"
      >
        <stop stopColor="#FA51D3" />
        <stop offset={0.959} stopColor="#FA51D3" stopOpacity={0} />
      </linearGradient>
      <linearGradient
        id="plugg"
        x1={6.749}
        y1={21.709}
        x2={10.18}
        y2={13.233}
        gradientUnits="userSpaceOnUse"
      >
        <stop stopColor="#FFE700" />
        <stop offset={1} stopColor="#FFE700" stopOpacity={0} />
      </linearGradient>
      <clipPath id="pluga">
        <path fill="#fff" d="M0 0h18v27H0z" />
      </clipPath>
    </defs>
  </svg>
);

const BitfinityLogo = (props: SVGProps<SVGSVGElement>) => (
  <svg
    width={42}
    height={42}
    viewBox="0 0 1080 1080"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    {...props}
  >
    <path
      fillRule="evenodd"
      clipRule="evenodd"
      d="M1080 540c0 298.234-241.766 540-540 540C241.766 1080 0 838.234 0 540 0 241.766 241.766 0 540 0c298.234 0 540 241.766 540 540Zm-540 510.41c281.892 0 510.41-228.518 510.41-510.41 0-281.892-228.518-510.411-510.41-510.411C258.108 29.589 29.589 258.108 29.589 540S258.108 1050.41 540 1050.41Z"
      fill="url(#bitfinitya)"
    />
    <mask
      id="bitfinityb"
      maskUnits="userSpaceOnUse"
      x={31}
      y={29}
      width={1020}
      height={1020}
      style={{
        maskType: "alpha",
      }}
    >
      <circle cx={541} cy={539} r={510} fill="#D9D9D9" />
    </mask>
    <g mask="url(#bitfinityb)">
      <circle
        cx={541}
        cy={539}
        r={540.824}
        fill="#00013A"
        stroke="url(#bitfinityc)"
        strokeWidth={61.648}
      />
      <g filter="url(#bitfinityd)">
        <g filter="url(#bitfinitye)">
          <ellipse
            cx={733.018}
            cy={1358.61}
            rx={993.649}
            ry={507.501}
            transform="rotate(-6.481 733.018 1358.61)"
            fill="#783DFF"
          />
        </g>
        <g filter="url(#bitfinityf)">
          <path
            d="M1427.81 936.232c133.2-87.8 171.95-177.853 268.1-302.741 185.61-241.075 187.94-443.177 387.86-673.202 407.91-469.35 138.95 1379.791-487.94 1506.251-394.08 79.5-1353.086-218.03-979.612-358.73 149.153-56.19 253.884-6.14 411.042-38.77 162.2-33.69 264.63-43.21 400.55-132.808Z"
            fill="url(#bitfinityg)"
          />
        </g>
        <g filter="url(#bitfinityh)">
          <path
            d="M-603.529 1076.3c-306.798 10.82-506.091 85.89-698.491 263.09-389.76 359 1918.494 495.97 1591.72 94.46-206.037-253.16-501.351-371.37-893.229-357.55Z"
            fill="#006FFF"
          />
        </g>
        <g filter="url(#bitfinityi)">
          <path
            d="M-379.764 1113.3c-197.738 13.01-326.795 86-452.325 255.82-254.301 344.03 1231.472 453.31 1024.553 75.36-130.467-238.31-319.653-347.8-572.228-331.18Z"
            fill="#0FF"
          />
        </g>
      </g>
      <g filter="url(#bitfinityj)">
        <g filter="url(#bitfinityk)">
          <path
            d="M-599.617 1501.42c298.189 72.97 478.056 186.99 630.406 399.61 308.634 430.74-1979.259 95.54-1577.679-231.14 253.21-205.98 566.39-261.68 947.273-168.47Z"
            fill="#006FFF"
          />
        </g>
        <path
          d="M-826.233 1492.15c190.963 52.94 302.484 150.64 390.864 342.44 179.041 388.55-1297.911 193.47-1018.471-134.52 176.19-206.8 383.69-275.55 627.607-207.92Z"
          fill="#0FF"
        />
      </g>
    </g>
    <g clipPath="url(#bitfinityl)">
      <path
        d="M120.569 540.415a195.538 195.538 0 0 0 120.708 180.67 195.546 195.546 0 0 0 213.108-42.394l1.047-1.397 209.509-236.046a137.938 137.938 0 0 1 98.119-40.505 139.674 139.674 0 0 1 139.672 139.672A139.668 139.668 0 0 1 763.06 680.087a137.907 137.907 0 0 1-53.112-10.435 137.907 137.907 0 0 1-45.007-30.07l-29.681-33.521a27.956 27.956 0 0 0-48.851 16.778 27.947 27.947 0 0 0 6.95 20.235l30.378 34.22 1.048 1.397a195.547 195.547 0 0 0 276.55 0A195.54 195.54 0 0 0 763.06 344.874a193.797 193.797 0 0 0-138.275 57.266l-1.048 1.397-209.508 236.045a137.917 137.917 0 0 1-98.119 40.505 139.672 139.672 0 1 1 0-279.344 137.926 137.926 0 0 1 98.119 40.505l29.681 33.521a27.952 27.952 0 1 0 41.901-37.013l-30.379-34.219-1.047-1.397a195.545 195.545 0 0 0-213.108-42.394 195.538 195.538 0 0 0-120.708 180.669Z"
        fill="url(#bitfinitym)"
      />
      <path
        d="M296.121 590.221v-11.073h-16.61v-11.073h11.073V512.71h-11.073v-11.073h16.61v-11.073h11.073v11.073h11.073v-11.073h11.073v11.765c4.799 1.292 8.766 3.897 11.904 7.817 3.137 3.924 4.706 8.469 4.706 13.637 0 2.676-.462 5.236-1.384 7.679a21.896 21.896 0 0 1-3.876 6.578c3.23 1.937 5.836 4.567 7.818 7.889 1.985 3.322 2.978 7.013 2.978 11.073 0 6.09-2.168 11.304-6.505 15.641s-9.551 6.505-15.641 6.505v11.073h-11.073v-11.073h-11.073v11.073h-11.073Zm5.536-55.365h22.147c3.045 0 5.652-1.085 7.823-3.255 2.166-2.167 3.25-4.773 3.25-7.818s-1.084-5.653-3.25-7.823c-2.171-2.167-4.778-3.25-7.823-3.25h-22.147v22.146Zm0 33.219h27.683c3.045 0 5.653-1.083 7.823-3.25 2.167-2.17 3.25-4.778 3.25-7.823 0-3.045-1.083-5.653-3.25-7.823-2.17-2.167-4.778-3.25-7.823-3.25h-27.683v22.146Z"
        fill="#E3316E"
      />
      <path
        d="M748.119 590.221v-11.073H731.51v-11.073h11.073V512.71H731.51v-11.073h16.609v-11.073h11.074v11.073h11.073v-11.073h11.073v11.765c4.798 1.292 8.766 3.897 11.903 7.817 3.138 3.924 4.706 8.469 4.706 13.637 0 2.676-.461 5.236-1.384 7.679a21.894 21.894 0 0 1-3.875 6.578c3.229 1.937 5.835 4.567 7.817 7.889 1.986 3.322 2.979 7.013 2.979 11.073 0 6.09-2.169 11.304-6.506 15.641-4.336 4.337-9.55 6.505-15.64 6.505v11.073h-11.073v-11.073h-11.073v11.073h-11.074Zm5.537-55.365h22.146c3.045 0 5.653-1.085 7.823-3.255 2.167-2.167 3.25-4.773 3.25-7.818s-1.083-5.653-3.25-7.823c-2.17-2.167-4.778-3.25-7.823-3.25h-22.146v22.146Zm0 33.219h27.683c3.045 0 5.653-1.083 7.823-3.25 2.166-2.17 3.25-4.778 3.25-7.823 0-3.045-1.084-5.653-3.25-7.823-2.17-2.167-4.778-3.25-7.823-3.25h-27.683v22.146Z"
        fill="#29ABE2"
      />
    </g>
    <defs>
      <filter
        id="bitfinityd"
        x={-1776.42}
        y={-933.328}
        width={5042.9}
        height={3238.54}
        filterUnits="userSpaceOnUse"
        colorInterpolationFilters="sRGB"
      >
        <feFlood floodOpacity={0} result="BackgroundImageFix" />
        <feBlend in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
        <feGaussianBlur
          stdDeviation={214.956}
          result="effect1_foregroundBlur_28_125"
        />
      </filter>
      <filter
        id="bitfinitye"
        x={-690.976}
        y={406.916}
        width={2847.99}
        height={1903.39}
        filterUnits="userSpaceOnUse"
        colorInterpolationFilters="sRGB"
      >
        <feFlood floodOpacity={0} result="BackgroundImageFix" />
        <feBlend in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
        <feGaussianBlur
          stdDeviation={217.502}
          result="effect1_foregroundBlur_28_125"
        />
      </filter>
      <filter
        id="bitfinityf"
        x={168.995}
        y={-478.345}
        width={2471.46}
        height={2320.67}
        filterUnits="userSpaceOnUse"
        colorInterpolationFilters="sRGB"
      >
        <feFlood floodOpacity={0} result="BackgroundImageFix" />
        <feBlend in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
        <feGaussianBlur
          stdDeviation={181.252}
          result="effect1_foregroundBlur_28_125"
        />
      </filter>
      <filter
        id="bitfinityh"
        x={-1781.51}
        y={640.209}
        width={2538.02}
        height={1473.07}
        filterUnits="userSpaceOnUse"
        colorInterpolationFilters="sRGB"
      >
        <feFlood floodOpacity={0} result="BackgroundImageFix" />
        <feBlend in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
        <feGaussianBlur
          stdDeviation={217.502}
          result="effect1_foregroundBlur_28_125"
        />
      </filter>
      <filter
        id="bitfinityi"
        x={-1151.47}
        y={821.653}
        width={1653.78}
        height={1150.26}
        filterUnits="userSpaceOnUse"
        colorInterpolationFilters="sRGB"
      >
        <feFlood floodOpacity={0} result="BackgroundImageFix" />
        <feBlend in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
        <feGaussianBlur
          stdDeviation={145.002}
          result="effect1_foregroundBlur_28_125"
        />
      </filter>
      <filter
        id="bitfinityj"
        x={-3682.93}
        y={-889.778}
        width={4172.37}
        height={3424.89}
        filterUnits="userSpaceOnUse"
        colorInterpolationFilters="sRGB"
      >
        <feFlood floodOpacity={0} result="BackgroundImageFix" />
        <feBlend in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
        <feGaussianBlur
          stdDeviation={214.956}
          result="effect1_foregroundBlur_28_125"
        />
      </filter>
      <filter
        id="bitfinityk"
        x={-2029.35}
        y={1022.69}
        width={2523.88}
        height={1517.51}
        filterUnits="userSpaceOnUse"
        colorInterpolationFilters="sRGB"
      >
        <feFlood floodOpacity={0} result="BackgroundImageFix" />
        <feBlend in="SourceGraphic" in2="BackgroundImageFix" result="shape" />
        <feGaussianBlur
          stdDeviation={217.502}
          result="effect1_foregroundBlur_28_125"
        />
      </filter>
      <linearGradient
        id="bitfinitya"
        x1={157.192}
        y1={121.747}
        x2={1007.88}
        y2={1050.41}
        gradientUnits="userSpaceOnUse"
      >
        <stop stopColor="#CD478F" />
        <stop offset={0.234} stopColor="#fff" />
        <stop offset={0.423} stopColor="#7230FF" />
        <stop offset={0.661} stopColor="#009BFF" />
        <stop offset={1} stopColor="#fff" />
      </linearGradient>
      <linearGradient
        id="bitfinityc"
        x1={158.5}
        y1={121.083}
        x2={1008.5}
        y2={1049}
        gradientUnits="userSpaceOnUse"
      >
        <stop stopColor="#CD478F" />
        <stop offset={0.234} stopColor="#fff" />
        <stop offset={0.423} stopColor="#7230FF" />
        <stop offset={0.661} stopColor="#009BFF" />
        <stop offset={1} stopColor="#fff" />
      </linearGradient>
      <linearGradient
        id="bitfinityg"
        x1={1813.2}
        y1={428.212}
        x2={1181.97}
        y2={1226.61}
        gradientUnits="userSpaceOnUse"
      >
        <stop stopColor="#994C7D" />
        <stop offset={1} stopColor="#BD609B" />
      </linearGradient>
      <radialGradient
        id="bitfinitym"
        cx={0}
        cy={0}
        r={1}
        gradientUnits="userSpaceOnUse"
        gradientTransform="rotate(27.35 -880.65 1215.061) scale(130.293 273.893)"
      >
        <stop offset={0.114} stopColor="#29ABE2" />
        <stop offset={0.173} stopColor="#29ABE2" />
        <stop offset={0.284} stopColor="#EE2A67" />
        <stop offset={0.529} stopColor="#522785" />
        <stop offset={0.638} stopColor="#D71F7A" />
        <stop offset={0.924} stopColor="#F9A137" />
        <stop offset={0.993} stopColor="#29ABE2" />
      </radialGradient>
      <clipPath id="bitfinityl">
        <path
          fill="#fff"
          transform="translate(92.648 93.45)"
          d="M0 0h893.901v893.901H0z"
        />
      </clipPath>
    </defs>
  </svg>
)
