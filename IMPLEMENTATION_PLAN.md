# План реализации: ODCS ETL Knowledge System

Сводный документ. Объединяет план пользователя, предложения агента и текущее состояние vault-а. Является roadmap-ом для последовательной реализации.

---

## Анализ пересечений

### Твой план vs предложения агента

| Твой шаг | Мой шаг | Решение |
| :---- | :---- | :---- |
| Python скрипт → Confluence | MCP Confluence (real-time) | **Оба нужны.** Python \= bulk ETL для первичного наполнения. MCP \= интерактивный on-demand доступ. Python идёт первым. |
| Rules/skills → MD по шаблону | g1-extract.skill.md | **Одно и то же**, но уточнение: Python делает структурную конвертацию HTML→MD, skill делает семантическую нормализацию под шаблон. |
| GraphRAG wiki (Карпатый) | Vault wiki (CLAUDE.md) | **Расширение существующего.** Vault — правильный контейнер. Нужно добавить явное извлечение узлов, связей и graph-index. |
| skills.md для ODCS маппинга | g1-generate.skill.md | **Одно и то же**, но шире: нужен набор из трёх skills (extract \+ gap \+ generate). |
| skills.md для Scala Spark | g2-codegen.skill.md | **Одно и то же**, но точнее: три отдельных skill (model \+ operations \+ scaffold). |
| Wiki \+ Contract как backbone | Phase 6 | **Полное совпадение.** Wiki \= навигация/контекст. Contract \= авторитетная спека. |

### Что уже сделано (Фаза 0\)

- `CLAUDE.md` / `GEMINI.md` — операционный контракт агента ✅  
- `wiki/concepts/odcs/section-mapping.md` — полный маппинг аналитика → контракт ✅  
- `wiki/concepts/odcs/spec-changelog.md` — различия v1 vs v2 ✅  
- `wiki/goals/odcs-doc-agent.md` — G1 чеклист ✅  
- `wiki/goals/etl-project-template.md` — G2 чеклист ✅  
- `wiki/sources/odcs/partner-tdp-example.md` — 5 реальных паттернов ✅

---

## Фаза 1 — Выгрузка Confluence

**Что делаем:** Python-скрипт, который подключается к Confluence по API, находит родительскую страницу и рекурсивно выгружает все дочерние страницы аналитики.

**Артефакты:**

scripts/

  confluence\_exporter.py   ← выгрузка дочерних страниц → raw HTML/MD

  normalize.py             ← конвертация в шаблон analisisy\_v1.md

  config.yaml              ← base\_url, space\_key, parent\_page\_id, auth

raw/sources/confluence/

  YYYY-MM-DD-\<vitrina-name\>.md   ← один файл на аналитику

**Ключевые решения:**

- Confluence API v2 (REST) или v1?  
- Формат выгрузки: Confluence storage format (XML) → MD или Confluence→PDF→MD?  
- Аутентификация: personal access token или OAuth?  
- Как идентифицировать страницы с аналитикой среди дочерних? (по метке, по шаблону заголовка?)

**Связь с моим предложением MCP:** MCP Confluence server добавляется поверх скрипта — для интерактивного обновления отдельных страниц без перезапуска полной выгрузки.

---

## Фаза 2 — GraphRAG Wiki (метод Карпатого)

**Что делаем:** Превращаем набор MD-аналитик в связанный граф знаний. Каждая страница аналитики — узел. Источники данных, трансформации, поля — тоже узлы. Рёбра \= зависимости, lineage, общие источники.

**Метод Карпатого применительно к задаче:** Кейс Карпатого — LLM как активный редактор: читает документ, извлекает сущности и связи, записывает их в структурированный граф, обновляет граф при поступлении новой информации. Ключевое — не плоский поиск, а **обход графа**: чтобы ответить на вопрос, агент идёт по рёбрам от нужного узла.

**Узлы графа:**

vitrina/\<name\>        ← аналитика (центральный узел)

source/\<alias\>        ← источник данных (ЕСС, реплика, справочник)

field/\<vitrina\>/\<name\>← поле витрины

transform/\<operation\> ← тип трансформации (join, window и т.д.)

pattern/\<name\>        ← паттерн (temporal-join, parametrized-filter и т.д.)

**Рёбра:**

vitrina → uses → source

vitrina → produces → field

field → lineage → field (другой витрины или источника)

vitrina → uses\_pattern → pattern

transform → instance\_of → pattern

**Артефакты:**

wiki/vitrina/\<name\>.md          ← узел аналитики

wiki/sources/confluence/\<name\>.md  ← source summary (уже в CLAUDE.md)

wiki/entities/\<source-alias\>.md ← узел источника

wiki/graph-index.md             ← adjacency map всего графа

graphrag-ingest.skill.md        ← правила извлечения узлов и рёбер при ingest

**Ключевые решения:**

- Формат graph-index: YAML adjacency list или MD таблицы?  
- Как обрабатывать пересечения: одна витрина использует источник другой витрины?  
- Глубина обхода при query: 1 hop или 2 hop по умолчанию?

---

## Фаза 3 — G1: Генерация ODCS контракта

**Что делаем:** Три skill-файла, которые вместе преобразуют MD-аналитику в набор YAML-файлов контракта по ПНД internal format v2.

### 3.1 — `skills/g1-extract.skill.md`

Правила парсинга каждой из 13 секций. Не промпт — детерминированная инструкция: "Если секция `## Источники данных` содержит подраздел `### Подписки ЕСС`, извлеки каждую строку таблицы как объект `{id, name, description}` в `sourceSystems[]`."

Опирается на `section-mapping.md` — все правила ссылаются на конкретные поля.

Выход: структурированный JSON промежуточный объект (не YAML, не контракт — промежуточное представление).

### 3.2 — `skills/g1-gap.skill.md`

Правила обнаружения GAP-ов и формирования вопросов аналитику.

GAP-1: партицирование отсутствует →

  Вопрос: "По каким полям секционируется таблица {targetTable}?

           Периодичность партиций: daily / monthly / none?"

GAP-2: условия удаления отсутствуют →

  Вопрос: "Нужна ли очистка таблицы перед записью?

           Если да — по каким условиям удаляются строки?"

GAP-3: историческая загрузка →

  Вопрос: "С какой даты нужна первая историческая загрузка?

           Формат: YYYY-MM-DD или 'не требуется'"

Режим: агент задаёт вопросы по одному, ждёт ответа, вносит в промежуточный JSON, только потом переходит к generate. Не задаёт все вопросы сразу.

### 3.3 — `skills/g1-generate.skill.md`

Правила заполнения каждой из 8 секций контракта из промежуточного JSON. Включает few-shot примеры из `partner_tdp` для каждого типа операции.

Выход: 8 YAML файлов в `contracts/<vitrina-name>/`

contracts/

  vitrina-komissiy/

    fundamentals.yaml

    inputParameters.yaml

    loadingStrategy.yaml

    sourceSystems.yaml

    transformation\_flow.yaml

    schema.yaml

    quality.yaml

    references.yaml

**Ключевые решения:**

- Промежуточный JSON — хранить на диск или только в контексте агента?  
- Как обрабатывать аналитики где трансформации описаны нестандартно?  
- Нужен ли единый `<name>_v2.yaml` в дополнение к split-файлам?

---

## Фаза 4 — Валидация контракта

**Что делаем:** Два уровня проверки сгенерированного контракта.

### 4.1 — `schemas/contract.schema.json`

JSON Schema для структурной валидации. Проверяет:

- Все обязательные секции присутствуют  
- Типы полей корректны (string/date/int/timestamp)  
- `operation` — только из enum (read/filter/join/withColumn/window/aggregate/drop/select)  
- `step` в v2 — строка в snake\_case, не число  
- `spec_version` заполнен для ODCS страниц

Инструмент: `jsonschema` (Python) или `ajv` (Node.js).

### 4.2 — `skills/g1-validate.skill.md`

Бизнес-правила которые schema не поймает:

- Все `source` в transformation\_flow ссылаются на существующий `id` из sourceSystems или `alias` предыдущего шага  
- Все `lineage.sourceStep` в schema ссылаются на существующий `step` из transformation\_flow  
- Финальный шаг transformation\_flow — `select` или `withColumn` (не `read` или `drop`)  
- `loadingStrategy.targetTable` присутствует и в формате `schema.table`  
- Нет шагов без `alias`

### 4.3 — Цикл исправления

validate → errors? → fix (агент или аналитик) → validate → OK → следующая фаза

Паттерн: агент не исправляет молча — он формирует отчёт с конкретными строками и ожидает подтверждения перед правкой.

---

## Фаза 5 — G2: Кодогенерация Scala / Spark

**Что делаем:** Три skill-файла для генерации Scala/Spark ETL проекта из контракта.

### 5.1 — `skills/g2-model.skill.md`

Правила генерации Scala ADT из `transformation_flow` и `schema`:

// Из transformation\_flow\[\].operation → sealed trait

sealed trait Step { val alias: String }

case class ReadStep(alias: String, source: String,

                    filter: Option\[List\[String\]\]) extends Step

case class JoinStep(alias: String, left: String, right: String,

                    joinType: String, condition: String,

                    preFilter: Option\[List\[String\]\]) extends Step

// ... все 8 операций

// Из schema.columns\[\] → case class

case class VitrinaRow(inn: String, epk\_id: Long, ...)

// Из schema.columns\[\].type → StructType

val schema \= StructType(Seq(

  StructField("inn", StringType, nullable \= true),

  StructField("epk\_id", LongType, nullable \= true), ...

))

### 5.2 — `skills/g2-operations.skill.md`

По одному Spark-паттерну на каждую из 8 операций. Паттерны опираются на реальные примеры из `partner_tdp`:

// operation: filter → предикаты из контракта

def applyFilter(df: DataFrame, predicates: List\[String\]): DataFrame \=

  predicates.foldLeft(df)((acc, pred) \=\> acc.filter(expr(pred)))

// operation: join → с pre/postJoinFilter

def applyJoin(left: DataFrame, right: DataFrame, step: JoinStep): DataFrame \= {

  val filteredRight \= step.preFilter

    .map(preds \=\> applyFilter(right, preds))

    .getOrElse(right)

  left.join(filteredRight, expr(step.condition), step.joinType)

}

// operation: window → Window spec из контракта

def applyWindow(df: DataFrame, step: WindowStep): DataFrame \= {

  val spec \= Window.partitionBy(step.partitionBy.map(col): \_\*)

                   .orderBy(step.orderBy.map(col): \_\*)

  step.expressions.foldLeft(df)((acc, e) \=\>

    acc.withColumn(e.targetColumn, expr(e.logic).over(spec)))

}

### 5.3 — `skills/g2-scaffold.skill.md`

Правила генерации sbt проекта. Фиксирует открытые решения:

build.sbt               ← Scala 2.13, Spark 3.x, sbt

src/main/scala/

  contract/

    DataContract.scala  ← ADT для всей схемы контракта

    ContractLoader.scala ← circe/snakeyaml reader

  pipeline/

    PipelineExecutor.scala  ← запуск шагов по порядку

    StepDispatcher.scala    ← operation → Spark функция

    DataFrameRegistry.scala ← alias → DataFrame map

    steps/                  ← по файлу на каждый Step тип

  sink/

    HudiWriter.scala    ← loadingStrategy → Hudi write options

  params/

    InputParams.scala   ← inputParameters\[\] → case class

contracts/              ← YAML-файлы (input)

**Ключевые решения которые нужно принять до генерации:**

- Scala 2.13 или Scala 3?  
- Effect system: cats-effect / ZIO / plain Future?  
- Hudi write mode default: MOR или COW?  
- YAML reader: circe-yaml или snakeyaml?  
- Test framework: ScalaTest или MUnit?

---

## Фаза 6 — Backbone: Wiki \+ Data Contract

**Что делаем:** Связываем два источника истины так, чтобы агент мог использовать оба одновременно.

**Wiki (GraphRAG) отвечает на вопросы типа:**

- "Какие витрины используют источник `subj_org_idl`?"  
- "Какие паттерны джойнов встречаются чаще всего?"  
- "Как в других витринах решается проблема SCD Type 2?"

**Data Contract отвечает на вопросы типа:**

- "Какие поля у витрины X и откуда они берутся?"  
- "Какой метод загрузки у витрины X?"  
- "Что делает шаг `join_subj` в витрине X?"

**Правило использования в CLAUDE.md:**

При кодогенерации:

1\. Из wiki получить: паттерны, прецеденты, похожие витрины

2\. Из Data Contract получить: конкретные поля, шаги, источники этой витрины

3\. Объединить: применить паттерн из wiki к данным из контракта

---

## Итоговая карта артефактов

scripts/

  confluence\_exporter.py       ← Фаза 1

  normalize.py                 ← Фаза 1

  validate\_contract.py         ← Фаза 4

  config.yaml                  ← Фаза 1

skills/

  graphrag-ingest.skill.md     ← Фаза 2

  g1-extract.skill.md          ← Фаза 3.1

  g1-gap.skill.md              ← Фаза 3.2

  g1-generate.skill.md         ← Фаза 3.3

  g1-validate.skill.md         ← Фаза 4.2

  g2-model.skill.md            ← Фаза 5.1

  g2-operations.skill.md       ← Фаза 5.2

  g2-scaffold.skill.md         ← Фаза 5.3

schemas/

  contract.schema.json         ← Фаза 4.1

raw/sources/confluence/        ← Фаза 1 (наполняется скриптом)

wiki/                          ← Фаза 2 (наполняется агентом)

  graph-index.md               ← Фаза 2

  vitrina/\*.md                 ← Фаза 2

contracts/                     ← Фаза 3 (генерируется агентом)

  \<vitrina-name\>/

    \*.yaml

src/                           ← Фаза 5 (генерируется агентом)

  main/scala/...

---

## Порядок реализации

| \# | Что | Зависит от | Выход |
| :---- | :---- | :---- | :---- |
| 1 | `confluence_exporter.py` | Confluence API access | `raw/sources/confluence/*.md` |
| 2 | `normalize.py` | Шаг 1 \+ шаблон analisisy\_v1 | Нормализованные MD |
| 3 | `graphrag-ingest.skill.md` | Шаг 2 \+ vault structure | `wiki/vitrina/*.md` \+ graph-index |
| 4 | `g1-extract.skill.md` | section-mapping.md (готово) | Промежуточный JSON |
| 5 | `g1-gap.skill.md` | Шаг 4 | Список вопросов аналитику |
| 6 | `g1-generate.skill.md` | Шаги 4-5 \+ partner\_tdp | YAML контракт (8 файлов) |
| 7 | `contract.schema.json` | Шаблоны контракта (готово) | Структурная валидация |
| 8 | `g1-validate.skill.md` | Шаги 6-7 | Бизнес-валидация |
| 9 | Принять tech decisions | — | Зафиксировать Scala/Hudi выборы |
| 10 | `g2-model.skill.md` | Шаг 9 \+ контракт схема | `DataContract.scala` |
| 11 | `g2-operations.skill.md` | Шаги 9-10 \+ partner\_tdp | `steps/*.scala` |
| 12 | `g2-scaffold.skill.md` | Шаги 9-11 | sbt проект |

---

## Открытые вопросы (нужно решить до старта)

### Фаза 1

- Какой Confluence: Cloud или Server/DC?  
- Как идентифицировать страницы с аналитикой? (метка, шаблон, родительская страница?)  
- Есть ли уже MD-экспорт или нужно конвертировать из HTML/storage format?

### Фаза 2 (GraphRAG)

- Глубина графа: сколько хопов при query?  
- Нужен ли отдельный vector index или достаточно wiki-ссылок?

### Фаза 5 (Scala)

- Scala 2.13 или 3?  
- Effect system?  
- Hudi: MOR или COW по умолчанию?

