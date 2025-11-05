import Fastify from 'fastify';
import { v4 as uuidv4 } from 'uuid';
import dotenv from 'dotenv';
import { enqueueJob } from './jobQueue';
import { getJobStatus } from './db';

dotenv.config();
const fastify = Fastify({ logger: true });

const validApiKeys = (process.env.API_KEYS || '').split(',').map(s => s.trim()).filter(Boolean);

fastify.post('/v1/generate', async (req, reply) => {
    const body = req.body as any;
    if (!body?.prompt || typeof body.prompt !== 'string') {
        return reply.status(400).send({ error: 'prompt is required' });
    }

    const authHeader = (req.headers['authorization'] || '') as string;
    const token = authHeader.replace(/^Bearer\s+/i, '');
    if (!validApiKeys.includes(token)) {
        return reply.status(401).send({ error: 'unauthorized' });
    }

    const jobId = uuidv4();

    // Insert minimal job record via worker (worker upsert handles missing job),
    // or optionally create here (not required for local scaffold).
    await enqueueJob({ jobId, prompt: body.prompt, refs: body.reference_image_urls || [] });

    return reply.status(202).send({ jobId, statusUrl: `/v1/result/${jobId}` });
});

fastify.get('/v1/result/:jobId', async (req, reply) => {
    const { jobId } = req.params as any;
    const job = await getJobStatus(jobId);
    if (!job) return reply.status(404).send({ error: 'not found' });
    return reply.send(job);
});

const start = async () => {
    try {
        await fastify.listen({ port: Number(process.env.PORT) || 3000, host: '0.0.0.0' });
    } catch (err) {
        fastify.log.error(err);
        process.exit(1);
    }
};

start();
