export interface Item {
  id: number;
  title: string;
  description: string;
  done: boolean;
  owner_sub: string;
  owner_name: string | null;
  created_at: string;
}

export interface Me {
  sub: string;
  username: string | null;
  email: string | null;
  first_name: string | null;
  last_name: string | null;
  roles: string[];
}
