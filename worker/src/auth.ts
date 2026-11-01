// Verifies Firebase ID tokens without the Admin SDK.
import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from 'jose';

const GOOGLE_JWKS = new URL(
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com',
);

export type TokenVerifier = (token: string) => Promise<string>;

export const googleKeys = (): JWTVerifyGetKey => createRemoteJWKSet(GOOGLE_JWKS);

/** Returns a function that resolves to the user's UID, or rejects if the token is invalid. */
export function createVerifier(projectId: string, keys: JWTVerifyGetKey): TokenVerifier {
  return async (token) => {
    const { payload } = await jwtVerify(token, keys, {
      issuer: `https://securetoken.google.com/${projectId}`,
      audience: projectId,
      algorithms: ['RS256'],
    });
    if (!payload.sub) throw new Error('Token has no subject.');
    return payload.sub;
  };
}
