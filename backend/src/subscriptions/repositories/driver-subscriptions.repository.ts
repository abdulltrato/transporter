import { randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/services/database.service';
import { DriverSubscriptionEntity } from '../entities/driver-subscription.entity';
import { SubscriptionPaymentMethod } from '../enums/subscription-payment-method.enum';
import { SubscriptionPlan } from '../enums/subscription-plan.enum';
import { SubscriptionStatus } from '../enums/subscription-status.enum';

export interface CreateDriverSubscriptionInput {
  driverId: string;
  plan: SubscriptionPlan;
  paymentMethod: SubscriptionPaymentMethod;
  paymentReference: string;
  status: SubscriptionStatus;
  validationAvailableAt: Date;
  agentNotes?: string;
}

@Injectable()
export class DriverSubscriptionsRepository {
  constructor(private readonly database: DatabaseService) {}

  async create(input: CreateDriverSubscriptionInput): Promise<DriverSubscriptionEntity> {
    const now = new Date();
    const result = await this.database.query<DriverSubscriptionRow>(
      `
        INSERT INTO driver_subscriptions (
          id,
          driver_id,
          plan,
          payment_method,
          payment_reference,
          status,
          validation_available_at,
          agent_notes,
          created_at,
          updated_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
        RETURNING
          id,
          driver_id,
          plan,
          payment_method,
          payment_reference,
          status,
          validation_available_at,
          validated_at,
          starts_at,
          ends_at,
          agent_name,
          agent_notes,
          created_at,
          updated_at
      `,
      [
        randomUUID(),
        input.driverId,
        input.plan,
        input.paymentMethod,
        input.paymentReference,
        input.status,
        input.validationAvailableAt,
        input.agentNotes ?? null,
        now,
        now
      ]
    );

    return this.toEntity(result.rows[0]);
  }

  async findById(subscriptionId: string): Promise<DriverSubscriptionEntity | undefined> {
    const result = await this.database.query<DriverSubscriptionRow>(
      `
        SELECT
          id,
          driver_id,
          plan,
          payment_method,
          payment_reference,
          status,
          validation_available_at,
          validated_at,
          starts_at,
          ends_at,
          agent_name,
          agent_notes,
          created_at,
          updated_at
        FROM driver_subscriptions
        WHERE id = $1
        LIMIT 1
      `,
      [subscriptionId]
    );

    const row = result.rows[0];
    return row ? this.toEntity(row) : undefined;
  }

  async save(subscription: DriverSubscriptionEntity): Promise<DriverSubscriptionEntity> {
    const updatedAt = new Date();
    const result = await this.database.query<DriverSubscriptionRow>(
      `
        INSERT INTO driver_subscriptions (
          id,
          driver_id,
          plan,
          payment_method,
          payment_reference,
          status,
          validation_available_at,
          validated_at,
          starts_at,
          ends_at,
          agent_name,
          agent_notes,
          created_at,
          updated_at
        )
        VALUES (
          $1, $2, $3, $4, $5, $6, $7, $8,
          $9, $10, $11, $12, $13, $14
        )
        ON CONFLICT (id) DO UPDATE SET
          driver_id = EXCLUDED.driver_id,
          plan = EXCLUDED.plan,
          payment_method = EXCLUDED.payment_method,
          payment_reference = EXCLUDED.payment_reference,
          status = EXCLUDED.status,
          validation_available_at = EXCLUDED.validation_available_at,
          validated_at = EXCLUDED.validated_at,
          starts_at = EXCLUDED.starts_at,
          ends_at = EXCLUDED.ends_at,
          agent_name = EXCLUDED.agent_name,
          agent_notes = EXCLUDED.agent_notes,
          updated_at = EXCLUDED.updated_at
        RETURNING
          id,
          driver_id,
          plan,
          payment_method,
          payment_reference,
          status,
          validation_available_at,
          validated_at,
          starts_at,
          ends_at,
          agent_name,
          agent_notes,
          created_at,
          updated_at
      `,
      [
        subscription.id,
        subscription.driverId,
        subscription.plan,
        subscription.paymentMethod,
        subscription.paymentReference,
        subscription.status,
        subscription.validationAvailableAt,
        subscription.validatedAt ?? null,
        subscription.startsAt ?? null,
        subscription.endsAt ?? null,
        subscription.agentName ?? null,
        subscription.agentNotes ?? null,
        subscription.createdAt,
        updatedAt
      ]
    );

    return this.toEntity(result.rows[0]);
  }

  async findLatestPendingByDriverId(
    driverId: string
  ): Promise<DriverSubscriptionEntity | undefined> {
    return this.findLatestByStatus(driverId, SubscriptionStatus.PENDING_VALIDATION);
  }

  async findLatestActiveByDriverId(
    driverId: string
  ): Promise<DriverSubscriptionEntity | undefined> {
    const result = await this.database.query<DriverSubscriptionRow>(
      `
        SELECT
          id,
          driver_id,
          plan,
          payment_method,
          payment_reference,
          status,
          validation_available_at,
          validated_at,
          starts_at,
          ends_at,
          agent_name,
          agent_notes,
          created_at,
          updated_at
        FROM driver_subscriptions
        WHERE
          driver_id = $1
          AND status = $2
          AND ends_at IS NOT NULL
          AND ends_at > NOW()
        ORDER BY ends_at DESC
        LIMIT 1
      `,
      [driverId, SubscriptionStatus.ACTIVE]
    );

    const row = result.rows[0];
    return row ? this.toEntity(row) : undefined;
  }

  async listByDriverId(driverId: string): Promise<DriverSubscriptionEntity[]> {
    const result = await this.database.query<DriverSubscriptionRow>(
      `
        SELECT
          id,
          driver_id,
          plan,
          payment_method,
          payment_reference,
          status,
          validation_available_at,
          validated_at,
          starts_at,
          ends_at,
          agent_name,
          agent_notes,
          created_at,
          updated_at
        FROM driver_subscriptions
        WHERE driver_id = $1
        ORDER BY created_at DESC
      `,
      [driverId]
    );

    return result.rows.map((row) => this.toEntity(row));
  }

  async listPendingValidation(): Promise<DriverSubscriptionEntity[]> {
    const result = await this.database.query<DriverSubscriptionRow>(
      `
        SELECT
          id,
          driver_id,
          plan,
          payment_method,
          payment_reference,
          status,
          validation_available_at,
          validated_at,
          starts_at,
          ends_at,
          agent_name,
          agent_notes,
          created_at,
          updated_at
        FROM driver_subscriptions
        WHERE status = $1
        ORDER BY created_at ASC
      `,
      [SubscriptionStatus.PENDING_VALIDATION]
    );

    return result.rows.map((row) => this.toEntity(row));
  }

  async expirePastSubscriptions(driverId: string): Promise<number> {
    const result = await this.database.query(
      `
        UPDATE driver_subscriptions
        SET status = $2, updated_at = NOW()
        WHERE
          driver_id = $1
          AND status = $3
          AND ends_at IS NOT NULL
          AND ends_at <= NOW()
      `,
      [
        driverId,
        SubscriptionStatus.EXPIRED,
        SubscriptionStatus.ACTIVE
      ]
    );

    return result.rowCount ?? 0;
  }

  async expireAllActiveSubscriptions(driverId: string): Promise<number> {
    const result = await this.database.query(
      `
        UPDATE driver_subscriptions
        SET status = $2, updated_at = NOW()
        WHERE driver_id = $1 AND status = $3
      `,
      [
        driverId,
        SubscriptionStatus.EXPIRED,
        SubscriptionStatus.ACTIVE
      ]
    );

    return result.rowCount ?? 0;
  }

  private async findLatestByStatus(
    driverId: string,
    status: SubscriptionStatus
  ): Promise<DriverSubscriptionEntity | undefined> {
    const result = await this.database.query<DriverSubscriptionRow>(
      `
        SELECT
          id,
          driver_id,
          plan,
          payment_method,
          payment_reference,
          status,
          validation_available_at,
          validated_at,
          starts_at,
          ends_at,
          agent_name,
          agent_notes,
          created_at,
          updated_at
        FROM driver_subscriptions
        WHERE driver_id = $1 AND status = $2
        ORDER BY created_at DESC
        LIMIT 1
      `,
      [driverId, status]
    );

    const row = result.rows[0];
    return row ? this.toEntity(row) : undefined;
  }

  private toEntity(row: DriverSubscriptionRow): DriverSubscriptionEntity {
    return {
      id: row.id,
      driverId: row.driver_id,
      plan: row.plan,
      paymentMethod: row.payment_method,
      paymentReference: row.payment_reference,
      status: row.status,
      validationAvailableAt: new Date(row.validation_available_at),
      validatedAt: row.validated_at ? new Date(row.validated_at) : undefined,
      startsAt: row.starts_at ? new Date(row.starts_at) : undefined,
      endsAt: row.ends_at ? new Date(row.ends_at) : undefined,
      agentName: row.agent_name ?? undefined,
      agentNotes: row.agent_notes ?? undefined,
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at)
    };
  }
}

interface DriverSubscriptionRow {
  id: string;
  driver_id: string;
  plan: SubscriptionPlan;
  payment_method: SubscriptionPaymentMethod;
  payment_reference: string;
  status: SubscriptionStatus;
  validation_available_at: Date | string;
  validated_at: Date | string | null;
  starts_at: Date | string | null;
  ends_at: Date | string | null;
  agent_name: string | null;
  agent_notes: string | null;
  created_at: Date | string;
  updated_at: Date | string;
}
