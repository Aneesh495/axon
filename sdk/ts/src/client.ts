/**
 * Axon TypeScript Client Implementation.
 */

import { Subject, CheckRequest, CheckResponse, GraphQLExecutionResult } from './types';

export class AxonClient {
  private endpointUrl: string;
  private authToken?: string;

  constructor(endpointUrl: string = 'http://localhost:9080', authToken?: string) {
    this.endpointUrl = endpointUrl.replace(/\/+$/, '');
    this.authToken = authToken;
  }

  public async check(req: CheckRequest): Promise<CheckResponse> {
    const subjectStr = req.subject.relation
      ? `${req.subject.namespace}:${req.subject.id}#${req.subject.relation}`
      : `${req.subject.namespace}:${req.subject.id}`;

    const body = {
      namespace: req.namespace,
      object_id: req.objectId,
      permission: req.permission,
      subject: subjectStr,
    };

    return this.post<CheckResponse>('/api/v1/rebac/check', body);
  }

  public async query<T = Record<string, unknown>>(
    queryStr: string,
    variables?: Record<string, unknown>
  ): Promise<GraphQLExecutionResult<T>> {
    const body = {
      query: queryStr,
      variables: variables ?? {},
    };

    return this.post<GraphQLExecutionResult<T>>('/graphql', body);
  }

  private async post<T>(path: string, body: unknown): Promise<T> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    };

    if (this.authToken) {
      headers['Authorization'] = `Bearer ${this.authToken}`;
    }

    const resp = await fetch(`${this.endpointUrl}${path}`, {
      method: 'POST',
      headers,
      body: JSON.stringify(body),
    });

    if (!resp.ok) {
      const errText = await resp.text();
      throw new Error(`Axon HTTP error ${resp.status}: ${errText}`);
    }

    return (await resp.json()) as T;
  }
}
