import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

export async function getJobStatus(jobId: string) {
    return prisma.job.findUnique({ where: { id: jobId } });
}

export async function updateJobStatus(jobId: string, status: string, error?: string) {
    try {
        return await prisma.job.update({ where: { id: jobId }, data: { status, error_message: error } });
    } catch (err) {
        return await prisma.job.create({ data: { id: jobId, prompt: 'unknown', status, error_message: error } });
    }
}

export async function saveJobResult(jobId: string, s3Key: string, cloudfrontUrl: string) {
    return prisma.job.upsert({
        where: { id: jobId },
        update: { status: 'COMPLETED', result_s3_key: s3Key, result_cloudfront_url: cloudfrontUrl },
        create: { id: jobId, prompt: 'unknown', status: 'COMPLETED', result_s3_key: s3Key, result_cloudfront_url: cloudfrontUrl }
    });
}
