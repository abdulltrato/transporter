import {
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
  MinLength
} from 'class-validator';

export enum AgentValidationAction {
  APPROVE = 'approve',
  REJECT = 'reject'
}

export class AgentValidateSubscriptionDto {
  @IsEnum(AgentValidationAction)
  action!: AgentValidationAction;

  @IsString()
  @MinLength(2)
  @MaxLength(80)
  agentName!: string;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  notes?: string;
}
