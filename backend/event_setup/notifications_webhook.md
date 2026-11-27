# Event Setup — department notification webhook

When an admin submits a new Event Setup request, everyone who can approve it
gets a push notification through OneSignal. The OneSignal REST API key must
**never** ship inside the Flutter app, so the push is sent server-side from a
Hasura event trigger.

## Flow

1. The Flutter app inserts a row into `event_setup_requests` (status `pending`).
2. Hasura event trigger `event_setup_request_created` (Insert) POSTs the new row
   to the webhook.
3. The webhook calls `event_setup_notification_recipients(request_id)` and gets
   back `(user_id, department)` for every rule in
   `event_setup_approval_permissions` where
   `department` matches and `group_id IS NULL OR group_id = request.group_id`.
4. For each department that has recipients, it sends one OneSignal push to those
   users.

The app calls `OneSignal.login(profile.id)` at sign-in (see
`AppState.updateOneSignalUser`), so each user's OneSignal `external_id` is
their `profiles.id`.

> Owners override every department in the UI, but they are only notified when
> they have an explicit permission rule. Add a rule for the owner if they want
> those pushes too.

## Hasura event trigger

| Setting | Value |
| --- | --- |
| Table | `public.event_setup_requests` |
| Operations | Insert |
| Webhook URL | `{{EVENT_SETUP_WEBHOOK_URL}}` (env var) |
| Headers | `x-webhook-secret: {{EVENT_SETUP_WEBHOOK_SECRET}}` |
| Retries | 3, interval 10s |

## Recipient query (run with the admin secret)

```graphql
query Recipients($id: uuid!) {
  event_setup_notification_recipients(args: { p_request_id: $id }) {
    user_id
    department
  }
}
```

(Track `event_setup_notification_recipients` as a Hasura function first.
Expose it only to the `admin` role, so no app role can call it.)

## Reference handler (Node / TypeScript)

```ts
// POST /hooks/event-setup-request-created
export async function handler(req: Request): Promise<Response> {
  if (req.headers.get('x-webhook-secret') !== process.env.EVENT_SETUP_WEBHOOK_SECRET) {
    return new Response('forbidden', { status: 403 });
  }

  const body = await req.json();
  const row = body.event.data.new; // event_setup_requests row

  const recipients = await hasuraAdmin(
    `query ($id: uuid!) {
       event_setup_notification_recipients(args: { p_request_id: $id }) { user_id department }
     }`,
    { id: row.id },
  );

  const byDept = new Map<string, string[]>();
  for (const r of recipients.event_setup_notification_recipients) {
    byDept.set(r.department, [...(byDept.get(r.department) ?? []), r.user_id]);
  }

  const deptLabel: Record<string, { en: string; es: string }> = {
    administrator: { en: 'Administrator', es: 'Administrador' },
    security:      { en: 'Security',      es: 'Seguridad' },
    cleaning:      { en: 'Cleaning Team', es: 'Equipo de Limpieza' },
  };

  for (const [dept, userIds] of byDept) {
    await fetch('https://api.onesignal.com/notifications', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Key ${process.env.ONESIGNAL_REST_API_KEY}`,
      },
      body: JSON.stringify({
        app_id: 'a75771e7-9bd5-4497-adf3-18b7c8901bcb',
        target_channel: 'push',
        include_aliases: { external_id: userIds },
        headings: {
          en: `Event setup sign-off needed (${deptLabel[dept].en})`,
          es: `Se necesita aprobación de evento (${deptLabel[dept].es})`,
        },
        contents: { en: row.title, es: row.title },
        data: { route: '/event-setup', request_id: row.id },
      }),
    });
  }

  return new Response('ok');
}
```

Return a non-2xx status on OneSignal failures so Hasura retries.

## Push for edits (v3)

Edits to a submitted event insert rows into `event_setup_notifications`
(one per Cleaning/Security approver and owner). They already show in the
Events tab under **Updates**. To also send a phone push, add a second Hasura
event trigger:

| Setting | Value |
| --- | --- |
| Table | `public.event_setup_notifications` |
| Operations | Insert |
| Webhook URL | `{{EVENT_SETUP_WEBHOOK_URL}}/edited` |
| Headers | `x-webhook-secret: {{EVENT_SETUP_WEBHOOK_SECRET}}` |

The row already names its recipient, so the handler needs no query:

```ts
const row = body.event.data.new; // event_setup_notifications row
await sendPush([row.user_id], {
  en: `Event updated: ${row.title}`,
  es: `Evento actualizado: ${row.title}`,
}, { route: '/event-setup', request_id: row.request_id });
```
