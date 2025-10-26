export type JobStatus = 'queued' | 'processing' | 'done' | 'failed';

export interface ImageJob {
    jobId: string;
    prompt: string;
    size?: string;
    quality?: 'standard' | 'high';
    background?: 'transparent' | 'opaque';
    references?: Array<
        | { type: 'imageUrl'; url: string }
        | { type: 'base64'; data: string; filename?: string }
    >;
}

export interface JobManifest {
    jobId: string;
    status: JobStatus;
    error?: string;
    imageKey?: string;
    createdAt: string;
    updatedAt: string;
    request: Omit<ImageJob, 'jobId'>;
}
