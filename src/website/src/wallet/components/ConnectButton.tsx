import React, { SVGProps } from "react";
import { Button, Flex } from "../../components";
import { styled } from '../../stitches.config';
import { useAccount, useConnect } from "../hooks";


export function ConnectButton({
  dark = false,
  title = "Connect to Plug",
}: {
  dark?: boolean,
  title?: string,
}) {
  const [{ data: account }, disconnect] = useAccount();
  const [_, connect] = useConnect();

  if (account?.principal) {
    return (
      <Flex css={{'> * + *': {
        marginLeft: '0.75rem',
      }}}>
        <Button disabled>
          {shortPrincipal(account?.principal)}
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
    <PlugConnectButton onClick={() => connect()} dark={dark}>
      <div>
        {dark ? <PlugDark /> : <PlugLight />}
        <span>{title}</span>
      </div>
    </PlugConnectButton>
  );
}

function shortPrincipal(w: any): string {
  const wstr = `${w}`;
  const arr = wstr.split('-')
  if (arr.length <= 1) {
    return "";
  }
  return `${arr[0]}...${arr.slice(-1)[0]}`;
}

const PlugConnectButton = styled('button', {
  border: 'none',
  background: 'linear-gradient(93.07deg, #FFD719 0.61%, #F754D4 33.98%, #1FD1EC 65.84%, #48FA6B 97.7%)',
  padding: '2px',
  borderRadius: '10px',
  cursor: 'pointer',
  transition: 'transform 0.3s',

  '&:hover': {
    transform: 'scale(1.03)',
  },

  '& > div': {
    display: 'flex',
    flexDirection: 'row',
    alignItems: 'center',
    background: 'white',
    padding: '5px 12px',
    borderRadius: '10px',
    fontSize: '16px',
    fontWeight: 600,
  },

  '& .dark': {
    background: '#111827',
    color: 'white',
  },

  '& svg': {
    marginRight: '9px',
  },

  variants: {
    dark: {
      true: {
        '& > div': {
          background: '#111827',
          color: 'white',
        },
      }
    },
  },
});

const PlugDark = (props: SVGProps<SVGSVGElement>) => (
  <svg
    width={18}
    height={27}
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    {...props}
  >
    <g clipPath="url(#a)">
      <path
        d="M3.366.414c0-.229.179-.414.4-.414h1.826c.22 0 .4.185.4.414v6.248H3.365V.414ZM11.949.414c0-.229.179-.414.4-.414h1.826c.22 0 .4.185.4.414v6.248h-2.626V.414Z"
        fill="#fff"
      />
      <path
        d="M0 7.753c0-.6.47-1.088 1.052-1.088h15.89c.581 0 1.052.487 1.052 1.088v5.42c0 5.143-4.028 9.311-8.997 9.311S0 18.316 0 13.174v-5.42Z"
        fill="url(#b)"
      />
      <path
        d="M5.993 21.695H12v.776c0 1.126-.883 2.04-1.972 2.04H7.965c-1.089 0-1.972-.914-1.972-2.04v-.776Z"
        fill="url(#c)"
      />
      <path
        d="M6.966 24.184h4.062v1.456c0 .751-.589 1.36-1.315 1.36H8.281c-.726 0-1.315-.609-1.315-1.36v-1.456Z"
        fill="url(#d)"
      />
      <path
        fillRule="evenodd"
        clipRule="evenodd"
        d="M17.281 16.81c-1.386-5.236-6.017-9.084-11.517-9.084-2.09 0-4.055.556-5.764 1.532v3.915c0 4.053 2.501 7.5 5.994 8.78v.518c0 .749.39 1.404.972 1.759v1.41c0 .75.589 1.36 1.315 1.36h1.432c.726 0 1.315-.61 1.315-1.36v-1.41c.582-.355.972-1.01.972-1.76v-.517c2.38-.872 4.3-2.751 5.281-5.142Z"
        fill="url(#e)"
      />
      <path
        fillRule="evenodd"
        clipRule="evenodd"
        d="M15.13 19.985c-.44-5.246-4.695-9.362-9.88-9.362-1.927 0-3.727.57-5.25 1.555v.996c0 4.052 2.501 7.5 5.994 8.779v.518c0 .75.39 1.404.972 1.759v1.41c0 .751.589 1.36 1.315 1.36h1.432c.726 0 1.315-.609 1.315-1.36v-1.41c.582-.355.972-1.01.972-1.76v-.517a8.946 8.946 0 0 0 3.13-1.968Z"
        fill="url(#f)"
      />
      <path
        fillRule="evenodd"
        clipRule="evenodd"
        d="M12.01 21.951c-.187-4.276-3.595-7.682-7.773-7.682a7.548 7.548 0 0 0-3.974 1.128c.723 3.055 2.903 5.518 5.735 6.556v.518c0 .75.39 1.404.973 1.759v1.41c0 .751.588 1.36 1.314 1.36h1.433c.726 0 1.314-.609 1.314-1.36v-1.41c.582-.355.973-1.01.973-1.76v-.517l.005-.002Z"
        fill="url(#g)"
      />
    </g>
    <defs>
      <linearGradient
        id="b"
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
        id="c"
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
        id="d"
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
        id="e"
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
        id="f"
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
        id="g"
        x1={6.749}
        y1={21.709}
        x2={10.18}
        y2={13.233}
        gradientUnits="userSpaceOnUse"
      >
        <stop stopColor="#FFE700" />
        <stop offset={1} stopColor="#FFE700" stopOpacity={0} />
      </linearGradient>
      <clipPath id="a">
        <path fill="#fff" d="M0 0h18v27H0z" />
      </clipPath>
    </defs>
  </svg>
)

const PlugLight = (props: SVGProps<SVGSVGElement>) => (
  <svg
    width={18}
    height={27}
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    {...props}
  >
    <g clipPath="url(#a)">
      <path
        d="M3.366.414c0-.229.179-.414.4-.414h1.826c.22 0 .4.185.4.414v6.248H3.365V.414ZM11.949.414c0-.229.179-.414.4-.414h1.826c.22 0 .4.185.4.414v6.248h-2.626V.414Z"
        fill="#031514"
      />
      <path
        d="M0 7.753c0-.6.47-1.088 1.052-1.088h15.89c.581 0 1.052.487 1.052 1.088v5.42c0 5.143-4.028 9.311-8.997 9.311S0 18.316 0 13.174v-5.42Z"
        fill="url(#b)"
      />
      <path
        d="M5.993 21.695H12v.776c0 1.126-.883 2.04-1.972 2.04H7.965c-1.089 0-1.972-.914-1.972-2.04v-.776Z"
        fill="url(#c)"
      />
      <path
        d="M6.966 24.184h4.062v1.456c0 .751-.589 1.36-1.315 1.36H8.281c-.726 0-1.315-.609-1.315-1.36v-1.456Z"
        fill="url(#d)"
      />
      <path
        fillRule="evenodd"
        clipRule="evenodd"
        d="M17.281 16.81c-1.386-5.236-6.017-9.084-11.517-9.084-2.09 0-4.055.556-5.764 1.532v3.915c0 4.053 2.501 7.5 5.994 8.78v.518c0 .749.39 1.404.972 1.759v1.41c0 .75.589 1.36 1.315 1.36h1.432c.726 0 1.315-.61 1.315-1.36v-1.41c.582-.355.972-1.01.972-1.76v-.517c2.38-.872 4.3-2.751 5.281-5.142Z"
        fill="url(#e)"
      />
      <path
        fillRule="evenodd"
        clipRule="evenodd"
        d="M15.13 19.985c-.44-5.246-4.695-9.362-9.88-9.362-1.927 0-3.727.57-5.25 1.555v.996c0 4.052 2.501 7.5 5.994 8.779v.518c0 .75.39 1.404.972 1.759v1.41c0 .751.589 1.36 1.315 1.36h1.432c.726 0 1.315-.609 1.315-1.36v-1.41c.582-.355.972-1.01.972-1.76v-.517a8.946 8.946 0 0 0 3.13-1.968Z"
        fill="url(#f)"
      />
      <path
        fillRule="evenodd"
        clipRule="evenodd"
        d="M12.01 21.951c-.187-4.276-3.595-7.682-7.773-7.682a7.548 7.548 0 0 0-3.974 1.128c.723 3.055 2.903 5.518 5.735 6.556v.518c0 .75.39 1.404.973 1.759v1.41c0 .751.588 1.36 1.314 1.36h1.433c.726 0 1.314-.609 1.314-1.36v-1.41c.582-.355.973-1.01.973-1.76v-.517l.005-.002Z"
        fill="url(#g)"
      />
    </g>
    <defs>
      <linearGradient
        id="b"
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
        id="c"
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
        id="d"
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
        id="e"
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
        id="f"
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
        id="g"
        x1={6.749}
        y1={21.709}
        x2={10.18}
        y2={13.233}
        gradientUnits="userSpaceOnUse"
      >
        <stop stopColor="#FFE700" />
        <stop offset={1} stopColor="#FFE700" stopOpacity={0} />
      </linearGradient>
      <clipPath id="a">
        <path fill="#fff" d="M0 0h18v27H0z" />
      </clipPath>
    </defs>
  </svg>
);

