import { BigNumber, BigNumberish } from "@ethersproject/bignumber";

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

    // Strip training 0
    if (!pad) {
      const matches = fraction?.match(/^([0-9]*[1-9]|0)(0*)/);
      if (matches && matches.length > 0) {
        fraction = matches[0];
      }
    }

    const whole = value.div(multiplier).toString();
    if (multiplier.length === 1) {
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
