import { BigNumber, BigNumberish } from "@ethersproject/bignumber";
import { WithdrawalsError, TokenError, TransferError, NeuronsError } from "../../declarations/deposits/deposits.did.d.js";

const Zero = BigNumber.from(0);
const NegativeOne = BigNumber.from(-1);

export function units(value: BigNumberish, decimals: BigNumberish = 8, pad=false): string {
    if (decimals == null) { decimals = 0; }
    const multiplier = getMultiplier(decimals);

    // Make sure wei is a big number (convert as necessary)
    value = BigNumber.from(value);

    const negative = value.lt(Zero);
    if (negative) { value = value.mul(NegativeOne); }

    let fraction = value.mod(multiplier).toString();
    while (fraction.length < multiplier.length - 1) { fraction = "0" + fraction; }

    // Strip trailing 0s
    if (!pad) {
      fraction = fraction.replace(/0+$/, '');
    }

    const whole = value.div(multiplier).toString();
    if (multiplier.length === 1 || fraction.length === 0) {
        value = whole;
    } else {
        value = whole + "." + fraction;
    }

    if (negative) { value = "-" + value; }

    return value;
}

// Constant to pull zeros from for multipliers
let zeros = "0";
while (zeros.length < 256) { zeros += zeros; }

// Returns a string "1" followed by decimal "0"s
function getMultiplier(decimals: BigNumberish): string {

    if (typeof(decimals) !== "number") {
        try {
            decimals = BigNumber.from(decimals).toNumber();
        } catch (e) { }
    }

    if (typeof(decimals) === "number" && decimals >= 0 && decimals <= 256 && !(decimals % 1)) {
        return ("1" + zeros.substring(0, decimals));
    }

    throw new Error(`invalid decimal size: ${decimals}`);
}

export function shortPrincipal(w: any): string {
  const wstr = `${w}`;
  const arr = wstr.split('-')
  if (arr.length <= 1) {
    return "";
  }
  return `${arr[0]}...${arr.slice(-1)[0]}`;
}

export function time(nanoseconds: bigint, timeZone?: string): string {
    const d = new Date(Number(nanoseconds/BigInt(1_000_000)));
    return new Intl.DateTimeFormat(
        'default',
        timeZone ? {timeZone, timeZoneName: 'short'} : {}
    ).format(d);
}

export function delay(seconds: bigint): string {
    if (seconds <= 0) {
        return "instant"
    }
    // TODO: pluralization
    let s: string[] = [];
    const lop =(min: bigint, unit: string) => {
        if (seconds >= min) {
            let amount = seconds/BigInt(min);
            s.push(`${amount} ${unit}${amount == BigInt(1) ? "" : "s"}`);
            seconds = seconds % BigInt(min);
        }
    };
    lop(BigInt(31557600), "year");
    lop(BigInt(2592000), "month");
    lop(BigInt(86400), "day");
    lop(BigInt(3600), "hour");
    lop(BigInt(60), "minute");
    lop(BigInt(1), "second");
    return s.join(" ");
}

export function withdrawalsError(err: WithdrawalsError): string {
  if ( 'TransferError' in err ) {
    return transferError(err.TransferError);
  } else if ('NeuronsError' in err) {
    return neuronsError(err.NeuronsError);
  } else if ('InsufficientBalance' in err) {
    return "Insufficient balance in your account.";
  } else if ('InsufficientLiquidity' in err) {
    return "Insufficient protocol liquidity.";
  } else if ('InvalidAddress' in err) {
    return "Invalid address.";
  } else if ('Other' in err) {
    return err.Other;
  } else if  ('TokenError' in err) {
    return tokenError(err.TokenError);
  } else {
    return "An unexpected error occurred."
  }
}

export function neuronsError(_err: NeuronsError): string {
  // TODO: Implement this with more detail.
  return "An unexpected error occured.";
}

export function transferError(_err: TransferError): string {
  // TODO: Implement this with more detail.
  return "An unexpected error occured.";
}

export function tokenError(err: TokenError): string {
  if ('InsufficientAllowance' in err) {
    return "Insufficient stICP allowance.";
  } else if ('InsufficientBalance' in err) {
    return "Insufficient stICP balance.";
  } else if ('Unauthorized' in err) {
    return "Unauthorized";
  } else if ('Other' in err) {
    return err.Other;
  } else {
    return "An unexpected error occurred."
  }
}
