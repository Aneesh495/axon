/**
 * Axon TypeScript SDK Type Definitions.
 */

export interface Subject {
  namespace: string;
  id: string;
  relation?: string;
}

export interface CheckRequest {
  namespace: string;
  objectId: string;
  permission: string;
  subject: Subject;
}

export interface CheckResponse {
  allowed: boolean;
  depth: number;
  trace: string[];
}

export interface GraphQLExecutionResult<T = Record<string, unknown>> {
  data?: T;
  errors?: string[];
}
