import type { UpdateState } from 'src/types/events';

export type LogEntry = {
  line: string;
  state: UpdateState;
};
