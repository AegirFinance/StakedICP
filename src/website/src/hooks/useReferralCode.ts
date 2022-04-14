import React from 'react';
import { useLocalStorage } from "./useLocalStorage";

interface ReferralCode {
    code?: string;
    expiry?: number;
}

export function useReferralCode() : string | undefined {
    const [stored, setCode] = useLocalStorage<ReferralCode>("referral", {});

    React.useEffect(() => {
        const now = Date.now();
        if (stored?.expiry && stored.expiry > now) {
            // not expired yet.
            return;
        }

        const params = new URLSearchParams(window.location.search);
        const code = params.get("r");
        setCode(code ? {code, expiry: now+(86400*30*1000)} : null);
    }, [stored, setCode, window.location.search]);

    if (stored?.expiry && stored.expiry < Date.now()) {
        return undefined;
    }
    return stored?.code ?? undefined;
}
