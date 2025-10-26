import { s3PutJson, s3GetJson, s3PutBytes } from './aws.js';
import { JobManifest } from './types.js';
import { env } from './env.js';

export const manifestKey = (jobId: string) => `jobs/${jobId}.json`;

export async function writeManifest(m: JobManifest) {
    await s3PutJson(env.bucketName, manifestKey(m.jobId), m);
}

export async function readManifest(jobId: string) {
    return s3GetJson<JobManifest>(env.bucketName, manifestKey(jobId));
}

export async function writePng(jobId: string, bytes: Buffer) {
    const key = `images/${jobId}.png`;
    await s3PutBytes(env.bucketName, key, bytes, 'image/png');
    return key;
}
