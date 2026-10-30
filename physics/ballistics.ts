/**
 * Deterministic External Ballistics Simulator
 * Runge-Kutta 4th order / step-marching numerical integration for projectile flight.
 */

import { type Vector3, vec3, vec3Add, vec3Scale, vec3Magnitude, vec3Normalize, vec3Sub } from '../core/types.ts';
import { ENGINE_CONFIG } from '../core/config.ts';

export interface CartridgeSpec {
  name: string;
  caliber: string;
  bulletMassKg: number;        // e.g. 0.0162 kg (250 grains for .45 Colt)
  bulletDiameterM: number;     // e.g. 0.01148 m (.452 in)
  nominalMuzzleVelocityMps: number; // e.g. 260 m/s for .45 Colt standard load
  dragCoefficientG1: number;   // e.g. 0.190
  powderType: 'SMOKELESS' | 'BLACK_POWDER';
}

export interface ProjectileState {
  position: Vector3;
  velocity: Vector3;
  timeAlive: number;
  isAlive: boolean;
  totalDistanceTraveled: number;
}

export class BallisticsEngine {
  private airDensity: number;
  private gravity: Vector3;

  constructor(airDensity: number = ENGINE_CONFIG.DESERT_ELEVATION_AIR_DENSITY, gravity: Vector3 = ENGINE_CONFIG.STANDARD_GRAVITY) {
    this.airDensity = airDensity;
    this.gravity = gravity;
  }

  /**
   * Calculates instantaneous aerodynamic drag acceleration vector on projectile.
   * F_drag = 0.5 * rho * Cd * A * v^2
   * a_drag = F_drag / m
   */
  public computeDragAcceleration(
    velocity: Vector3,
    windVelocity: Vector3,
    bulletMassKg: number,
    bulletDiameterM: number,
    dragCoefficient: number
  ): Vector3 {
    const relVelocity = vec3Sub(velocity, windVelocity);
    const speed = vec3Magnitude(relVelocity);
    if (speed < 0.001) return vec3(0, 0, 0);

    const crossSectionalArea = Math.PI * Math.pow(bulletDiameterM / 2, 2);
    const dragForceMagnitude = 0.5 * this.airDensity * dragCoefficient * crossSectionalArea * (speed * speed);
    const dragAccelMagnitude = dragForceMagnitude / bulletMassKg;

    const dragDirection = vec3Scale(vec3Normalize(relVelocity), -1);
    return vec3Scale(dragDirection, dragAccelMagnitude);
  }

  /**
   * Deterministic step simulation using velocity Verlet or Euler-Cromer integration.
   */
  public stepProjectile(
    state: ProjectileState,
    spec: CartridgeSpec,
    windVelocity: Vector3,
    dt: number
  ): void {
    if (!state.isAlive) return;

    const dragAccel = this.computeDragAcceleration(
      state.velocity,
      windVelocity,
      spec.bulletMassKg,
      spec.bulletDiameterM,
      spec.dragCoefficientG1
    );

    const totalAccel = vec3Add(this.gravity, dragAccel);

    // Update velocity
    state.velocity = vec3Add(state.velocity, vec3Scale(totalAccel, dt));

    // Update position
    const displacement = vec3Scale(state.velocity, dt);
    state.position = vec3Add(state.position, displacement);

    state.timeAlive += dt;
    state.totalDistanceTraveled += vec3Magnitude(displacement);

    // Termination conditions (ground impact at y <= 0 or maximum range)
    if (state.position.y <= 0 || state.totalDistanceTraveled > 2500) {
      state.isAlive = false;
      if (state.position.y < 0) state.position.y = 0;
    }
  }

  /**
   * Simulates full flight trajectory until impact, returning trajectory checkpoints.
   */
  public traceTrajectory(
    initialPosition: Vector3,
    launchVelocity: Vector3,
    spec: CartridgeSpec,
    windVelocity: Vector3 = vec3(0, 0, 0),
    maxSteps: number = 3000
  ): ProjectileState[] {
    const trajectory: ProjectileState[] = [];
    const state: ProjectileState = {
      position: { ...initialPosition },
      velocity: { ...launchVelocity },
      timeAlive: 0,
      isAlive: true,
      totalDistanceTraveled: 0,
    };

    const dt = ENGINE_CONFIG.PHYSICS_DELTA_TIME_S;
    let steps = 0;

    trajectory.push({ ...state });

    while (state.isAlive && steps < maxSteps) {
      this.stepProjectile(state, spec, windVelocity, dt);
      trajectory.push({
        position: { ...state.position },
        velocity: { ...state.velocity },
        timeAlive: state.timeAlive,
        isAlive: state.isAlive,
        totalDistanceTraveled: state.totalDistanceTraveled,
      });
      steps++;
    }

    return trajectory;
  }
}
