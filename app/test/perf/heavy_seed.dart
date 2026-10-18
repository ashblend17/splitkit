/// The part of test/fixtures/sync/john.json that heavy_data.dart builds on: the `global` stream
/// (the built-in categories and dashboards) and the profile from the user's stream, shaped like the
/// fixture's `snapshots`. A copy, so the dataset can also be built where the test folder isn't, on
/// a phone (integration_test/perf_test.dart). ledger_perf_test.dart checks it still matches the
/// fixture (heavy_data.dart's heavySeedOf), and prints what it should be when it doesn't.
library;

const heavySeedJson = r'''
{
  "global": {
    "entities": [
      {
        "entity": "category",
        "entity_id": "2965731c-da35-5826-a263-1d92c2f5d6a1",
        "version": null,
        "data": {
          "id": "2965731c-da35-5826-a263-1d92c2f5d6a1",
          "key": "food",
          "label": "Food",
          "icon": "food",
          "scope": "all",
          "owner_id": null,
          "sort": 10,
          "kind": "need"
        }
      },
      {
        "entity": "category",
        "entity_id": "b92615d7-5600-5e62-8a96-38195d08dce7",
        "version": null,
        "data": {
          "id": "b92615d7-5600-5e62-8a96-38195d08dce7",
          "key": "transport",
          "label": "Transport",
          "icon": "transport",
          "scope": "all",
          "owner_id": null,
          "sort": 20,
          "kind": "need"
        }
      },
      {
        "entity": "category",
        "entity_id": "5474fb6d-07fb-557a-9bf4-560d10bee16d",
        "version": null,
        "data": {
          "id": "5474fb6d-07fb-557a-9bf4-560d10bee16d",
          "key": "shopping",
          "label": "Shopping",
          "icon": "shopping",
          "scope": "all",
          "owner_id": null,
          "sort": 30,
          "kind": "want"
        }
      },
      {
        "entity": "category",
        "entity_id": "ba3646aa-b081-5504-b51d-2a5f485150fc",
        "version": null,
        "data": {
          "id": "ba3646aa-b081-5504-b51d-2a5f485150fc",
          "key": "entertainment",
          "label": "Fun",
          "icon": "entertainment",
          "scope": "all",
          "owner_id": null,
          "sort": 40,
          "kind": "want"
        }
      },
      {
        "entity": "category",
        "entity_id": "c237ab49-4e1d-58ab-b1f1-1da9eb2c3769",
        "version": null,
        "data": {
          "id": "c237ab49-4e1d-58ab-b1f1-1da9eb2c3769",
          "key": "travel",
          "label": "Travel",
          "icon": "travel",
          "scope": "group",
          "owner_id": null,
          "sort": 50,
          "kind": "want"
        }
      },
      {
        "entity": "category",
        "entity_id": "ce5d7af5-d41e-5874-a2cf-0321e4d0ce5f",
        "version": null,
        "data": {
          "id": "ce5d7af5-d41e-5874-a2cf-0321e4d0ce5f",
          "key": "stay",
          "label": "Stay",
          "icon": "rent",
          "scope": "group",
          "owner_id": null,
          "sort": 60,
          "kind": "want"
        }
      },
      {
        "entity": "category",
        "entity_id": "81c9635a-b258-5ac2-bce7-a3619e4ebc93",
        "version": null,
        "data": {
          "id": "81c9635a-b258-5ac2-bce7-a3619e4ebc93",
          "key": "rent",
          "label": "Rent",
          "icon": "rent",
          "scope": "all",
          "owner_id": null,
          "sort": 70,
          "kind": "need"
        }
      },
      {
        "entity": "category",
        "entity_id": "a5fc7a4a-1bc0-5c91-94f5-51c7faa69855",
        "version": null,
        "data": {
          "id": "a5fc7a4a-1bc0-5c91-94f5-51c7faa69855",
          "key": "bills",
          "label": "Bills",
          "icon": "bills",
          "scope": "all",
          "owner_id": null,
          "sort": 80,
          "kind": "need"
        }
      },
      {
        "entity": "category",
        "entity_id": "42220069-ff05-57ab-8292-dc10b4f2ce83",
        "version": null,
        "data": {
          "id": "42220069-ff05-57ab-8292-dc10b4f2ce83",
          "key": "health",
          "label": "Health",
          "icon": "health",
          "scope": "personal",
          "owner_id": null,
          "sort": 90,
          "kind": "need"
        }
      },
      {
        "entity": "category",
        "entity_id": "6614cb5e-301f-57f1-85d4-ae8a8838fe7c",
        "version": null,
        "data": {
          "id": "6614cb5e-301f-57f1-85d4-ae8a8838fe7c",
          "key": "income",
          "label": "Income",
          "icon": "income",
          "scope": "personal",
          "owner_id": null,
          "sort": 100,
          "kind": "income"
        }
      },
      {
        "entity": "category",
        "entity_id": "45e00ef2-b34a-56d4-9d3a-4ad2456709aa",
        "version": null,
        "data": {
          "id": "45e00ef2-b34a-56d4-9d3a-4ad2456709aa",
          "key": "other",
          "label": "Other",
          "icon": "other",
          "scope": "all",
          "owner_id": null,
          "sort": 999,
          "kind": null
        }
      },
      {
        "entity": "layout",
        "entity_id": "7da7e79e-da27-59ae-9b9e-a581fb481285",
        "version": null,
        "data": {
          "scope": "group",
          "owner_id": null,
          "cards": [
            {
              "position": 1,
              "type": "total_spend",
              "title": "Total group spending",
              "period": "all_time",
              "source": "group_total",
              "params_json": {}
            },
            {
              "position": 2,
              "type": "spending_trend",
              "title": "Spending over time",
              "period": "all_time",
              "source": "group_daily",
              "params_json": {
                "bucket": "day"
              }
            },
            {
              "position": 3,
              "type": "spending_by_category",
              "title": "By category",
              "period": "all_time",
              "source": "group_by_category",
              "params_json": {}
            },
            {
              "position": 4,
              "type": "paid_by_member",
              "title": "Who paid",
              "period": "all_time",
              "source": "group_paid_by",
              "params_json": {}
            }
          ]
        }
      },
      {
        "entity": "layout",
        "entity_id": "a41c7792-5b73-523a-bb8f-40b66ce911f0",
        "version": null,
        "data": {
          "scope": "personal",
          "owner_id": null,
          "cards": [
            {
              "position": 1,
              "type": "spending_trend",
              "title": "Spending over time",
              "period": "last_6_months",
              "source": "personal_monthly",
              "params_json": {
                "bucket": "month"
              }
            },
            {
              "position": 2,
              "type": "spending_by_category",
              "title": "Spending by category",
              "period": "this_month",
              "source": "personal_by_category",
              "params_json": {}
            },
            {
              "position": 3,
              "type": "personal_vs_group",
              "title": "Personal vs group",
              "period": "this_month",
              "source": "scope_split",
              "params_json": {}
            },
            {
              "position": 4,
              "type": "average_daily",
              "title": "Average per day",
              "period": "this_month",
              "source": "personal_daily_avg",
              "params_json": {
                "compare": "previous_month"
              }
            },
            {
              "position": 5,
              "type": "spending_by_account",
              "title": "By account",
              "period": "this_month",
              "source": "personal_by_account",
              "params_json": {}
            },
            {
              "position": 6,
              "type": "spending_by_channel",
              "title": "By payment mode",
              "period": "this_month",
              "source": "personal_by_channel",
              "params_json": {}
            },
            {
              "position": 7,
              "type": "top_merchants",
              "title": "Top merchants",
              "period": "this_month",
              "source": "personal_top_merchants",
              "params_json": {}
            },
            {
              "position": 8,
              "type": "savings_rate",
              "title": "Savings rate",
              "period": "this_month",
              "source": "personal_savings_rate",
              "params_json": {}
            },
            {
              "position": 9,
              "type": "need_vs_want",
              "title": "Needs and wants",
              "period": "this_month",
              "source": "personal_need_want",
              "params_json": {}
            }
          ]
        }
      }
    ]
  },
  "user:49eaa721-4d30-5296-a193-d18818ade774": {
    "entities": [
      {
        "entity": "profile",
        "entity_id": "49eaa721-4d30-5296-a193-d18818ade774",
        "version": 1,
        "data": {
          "id": "49eaa721-4d30-5296-a193-d18818ade774",
          "name": "John Doe",
          "email": "admin@example.com",
          "avatar_url": null,
          "currency": "INR",
          "role": "admin",
          "created_at": "2026-06-20T06:30:00+00:00",
          "version": 1
        }
      }
    ]
  }
}
''';
