import { useCallback, useEffect, useState } from "react";
import {
  PageHeader,
  Card,
  FormField,
  Input,
  Textarea,
  Button,
  Tag,
  Switch,
  EmptyState,
  Spinner,
  Callout,
  useForm,
} from "@diametral/design-system/react";

import { api, ApiError } from "../lib/api";
import type { Item } from "../lib/types";

export default function Items() {
  const [items, setItems] = useState<Item[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      setItems(await api<Item[]>("/api/items"));
      setError(null);
    } catch (e) {
      setError((e as ApiError).message);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  // The Diametral form layer: state + validation in `useForm`, label/error
  // rendering via `<FormField>`.
  const form = useForm({
    initialValues: { title: "", description: "" },
    validate: (values) => {
      const errors: { title?: string } = {};
      if (!values.title.trim()) errors.title = "A title is required.";
      return errors;
    },
  });

  const onCreate = form.handleSubmit(async (values) => {
    try {
      await api<Item>("/api/items", {
        method: "POST",
        body: JSON.stringify({
          title: values.title.trim(),
          description: values.description.trim(),
        }),
      });
      form.reset();
      await load();
    } catch (e) {
      setError((e as ApiError).message);
    }
  });

  const toggleDone = async (item: Item) => {
    setItems((cur) =>
      cur
        ? cur.map((i) => (i.id === item.id ? { ...i, done: !i.done } : i))
        : cur,
    );
    try {
      await api<Item>(`/api/items/${item.id}`, {
        method: "PATCH",
        body: JSON.stringify({ done: !item.done }),
      });
    } catch (e) {
      setError((e as ApiError).message);
      await load(); // re-sync with the server on failure
    }
  };

  const remove = async (item: Item) => {
    try {
      await api<void>(`/api/items/${item.id}`, { method: "DELETE" });
      setItems((cur) => (cur ? cur.filter((i) => i.id !== item.id) : cur));
    } catch (e) {
      setError((e as ApiError).message);
    }
  };

  const titleReg = form.register("title");
  const descReg = form.register("description");

  return (
    <>
      <PageHeader
        title="Items"
        subtitle="Each item is stored in Postgres and scoped to your Keycloak user."
      />

      {error && (
        <Callout
          type="danger"
          heading="Something went wrong"
          style={{ marginBottom: 16 }}
        >
          {error}
        </Callout>
      )}

      <Card title="New item">
        <form onSubmit={onCreate} style={{ display: "grid", gap: 14 }}>
          <FormField label="Title" htmlFor="title" error={form.errors.title}>
            <Input
              id="title"
              placeholder="e.g. Prepare the demo"
              {...titleReg}
              value={String(titleReg.value ?? "")}
            />
          </FormField>
          <FormField label="Description" htmlFor="description" hint="Optional.">
            <Textarea
              id="description"
              rows={2}
              placeholder="A line or two of detail…"
              {...descReg}
              value={String(descReg.value ?? "")}
            />
          </FormField>
          <div>
            <Button variant="primary" type="submit" loading={form.isSubmitting}>
              Add item
            </Button>
          </div>
        </form>
      </Card>

      <div style={{ marginTop: 24 }}>
        {items === null ? (
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: 10,
              padding: 24,
            }}
          >
            <Spinner inline /> Loading items…
          </div>
        ) : items.length === 0 ? (
          <EmptyState
            title="No items yet"
            description="Create your first item above — it'll be saved to Postgres under your account."
          />
        ) : (
          <div style={{ display: "grid", gap: 10 }}>
            {items.map((item) => (
              <Card key={item.id}>
                <div
                  style={{ display: "flex", alignItems: "flex-start", gap: 16 }}
                >
                  <div style={{ flex: 1 }}>
                    <div
                      style={{ display: "flex", alignItems: "center", gap: 10 }}
                    >
                      <strong
                        style={{
                          textDecoration: item.done ? "line-through" : "none",
                          color: item.done ? "var(--ds-ink-faint)" : "inherit",
                        }}
                      >
                        {item.title}
                      </strong>
                      <Tag status={item.done ? "success" : "info"}>
                        {item.done ? "Done" : "Open"}
                      </Tag>
                    </div>
                    {item.description && (
                      <p
                        style={{
                          margin: "6px 0 0",
                          color: "var(--ds-ink-soft)",
                        }}
                      >
                        {item.description}
                      </p>
                    )}
                  </div>
                  <Switch checked={item.done} onChange={() => toggleDone(item)}>
                    Done
                  </Switch>
                  <Button onClick={() => remove(item)}>Delete</Button>
                </div>
              </Card>
            ))}
          </div>
        )}
      </div>
    </>
  );
}
