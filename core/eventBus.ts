/**
 * Decoupled Typed Event Bus
 * Facilitates event emission between Physics, Inventory, Survival, and World domains.
 */

export type EventHandler<T = any> = (payload: T) => void;

export interface EventMap {
  'weapon:fired': {
    weaponId: string;
    muzzleVelocity: number;
    caliber: string;
    barrelFouling: number;
    position: { x: number; y: number; z: number };
    direction: { x: number; y: number; z: number };
  };
  'weapon:jammed': {
    weaponId: string;
    malfunctionType: string;
    degradationIndex: number;
  };
  'weapon:cleaned': {
    weaponId: string;
    gritRemoved: number;
    foulingRemoved: number;
    newCondition: number;
  };
  'inventory:itemMoved': {
    itemId: string;
    sourceContainerId: string;
    targetContainerId: string;
    x: number;
    y: number;
  };
  'inventory:encumbranceChanged': {
    containerId: string;
    totalMassKg: number;
    centerOfMassOffset: { x: number; y: number; z: number };
  };
  'weather:conditionChanged': {
    previousCondition: string;
    newCondition: string;
    gritSuspensionDensity: number; // mg/m^3
    windSpeedMps: number;
    temperatureCelsius: number;
  };
  'survival:traumaApplied': {
    zone: string;
    severity: number;
    bleedingRate: number;
  };
  'survival:staminaDrained': {
    remainingStamina: number;
    maxStamina: number;
    drainRate: number;
  };
}

export class EventBus {
  private listeners: Map<keyof EventMap, Set<EventHandler>> = new Map();

  public on<K extends keyof EventMap>(event: K, handler: EventHandler<EventMap[K]>): () => void {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, new Set());
    }
    const handlers = this.listeners.get(event)!;
    handlers.add(handler as EventHandler);

    return () => {
      handlers.delete(handler as EventHandler);
    };
  }

  public emit<K extends keyof EventMap>(event: K, payload: EventMap[K]): void {
    const handlers = this.listeners.get(event);
    if (!handlers || handlers.size === 0) return;

    for (const handler of handlers) {
      try {
        handler(payload);
      } catch (err) {
        console.error(`[EventBus] Error in handler for event "${String(event)}":`, err);
      }
    }
  }

  public clear(): void {
    this.listeners.clear();
  }
}

// Global shared singleton instance
export const globalEventBus = new EventBus();
