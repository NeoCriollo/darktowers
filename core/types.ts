/**
 * Core Type Definitions & Primitives
 * The Path of Ka - Vertical Slice Architecture
 */

export type EntityId = string;
export type TimestampMs = number;
export type DeltaTimeSeconds = number;

export interface Vector3 {
  x: number;
  y: number;
  z: number;
}

export function vec3(x: number = 0, y: number = 0, z: number = 0): Vector3 {
  return { x, y, z };
}

export function vec3Add(a: Vector3, b: Vector3): Vector3 {
  return { x: a.x + b.x, y: a.y + b.y, z: a.z + b.z };
}

export function vec3Sub(a: Vector3, b: Vector3): Vector3 {
  return { x: a.x - b.x, y: a.y - b.y, z: a.z - b.z };
}

export function vec3Scale(v: Vector3, s: number): Vector3 {
  return { x: v.x * s, y: v.y * s, z: v.z * s };
}

export function vec3Magnitude(v: Vector3): number {
  return Math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
}

export function vec3Normalize(v: Vector3): Vector3 {
  const m = vec3Magnitude(v);
  if (m === 0) return { x: 0, y: 0, z: 0 };
  return { x: v.x / m, y: v.y / m, z: v.z / m };
}

export interface Ray {
  origin: Vector3;
  direction: Vector3;
}

export interface BoundingBox3D {
  min: Vector3;
  max: Vector3;
}

/**
 * Result pattern for deterministic, typed error handling without exceptions.
 */
export type Result<T, E = string> =
  | { success: true; value: T }
  | { success: false; error: E };

export function ok<T>(value: T): Result<T, never> {
  return { success: true, value };
}

export function err<E>(error: E): Result<never, E> {
  return { success: false, error };
}
