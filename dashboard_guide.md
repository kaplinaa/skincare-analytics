# 📊 Гайд по созданию Power BI дашборда
## D2C Skincare E-Commerce Analytics

---

## Подготовка данных в Power BI

### 1. Загрузка файлов
Откройте Power BI Desktop → **Get Data → Text/CSV** → загрузите все 6 файлов:
`Customers.csv`, `Orders.csv`, `Order_Items.csv`, `Products.csv`, `Returns.csv`, `Reviews.csv`

### 2. Настройка связей (Relationships)
Перейдите в **Model View** и создайте связи:

| От таблицы | Поле | К таблице | Поле | Тип |
|------------|------|-----------|------|-----|
| Orders | customer_id | Customers | customer_id | Many-to-One |
| Order_Items | order_id | Orders | order_id | Many-to-One |
| Order_Items | product_id | Products | product_id | Many-to-One |
| Returns | order_id | Orders | order_id | Many-to-One |
| Returns | product_id | Products | product_id | Many-to-One |
| Reviews | order_id | Orders | order_id | Many-to-One |
| Reviews | product_id | Products | product_id | Many-to-One |
| Reviews | customer_id | Customers | customer_id | Many-to-One |

### 3. Вычисляемые столбцы и меры (DAX)

Создайте в таблице Orders:
```dax
// Год заказа
Order Year = YEAR(Orders[order_date])

// Месяц-год для графика
Order YearMonth = FORMAT(Orders[order_date], "YYYY-MM")

// Сезон
Season = 
SWITCH(
    TRUE(),
    MONTH(Orders[order_date]) IN {12,1,2}, "Зима",
    MONTH(Orders[order_date]) IN {3,4,5},  "Весна",
    MONTH(Orders[order_date]) IN {6,7,8},  "Лето",
    "Осень"
)
```

Создайте Measures (меры) в отдельной таблице _Measures:
```dax
// Общая выручка (без отмен)
Total Revenue = 
CALCULATE(
    SUM(Orders[final_amount]),
    Orders[order_status] <> "Cancelled"
)

// Количество заказов
Total Orders = 
CALCULATE(
    COUNTROWS(Orders),
    Orders[order_status] <> "Cancelled"
)

// Средний чек
Avg Order Value = DIVIDE([Total Revenue], [Total Orders])

// Количество клиентов
Total Customers = DISTINCTCOUNT(Orders[customer_id])

// Процент возвратов
Return Rate = 
DIVIDE(
    DISTINCTCOUNT(Returns[return_id]),
    [Total Orders]
) * 100

// Средний рейтинг
Avg Rating = AVERAGE(Reviews[rating])
```

---

## Структура дашборда (3 страницы)

---

### 📄 Страница 1: Обзор бизнеса (Overview)

**Назначение:** Главная страница — быстрый взгляд на ключевые метрики.

#### KPI-карточки (вверху, горизонтально)
Добавьте 5 **Card** визуалов:
- 💰 **Total Revenue** — мера `[Total Revenue]`, формат: ₹#,##0
- 🛒 **Total Orders** — мера `[Total Orders]`
- 👩 **Total Customers** — мера `[Total Customers]`
- 🧾 **Avg Order Value** — мера `[Avg Order Value]`, формат: ₹#,##0
- 📦 **Return Rate** — мера `[Return Rate]`, формат: 0.0%

#### График 1: Динамика выручки по месяцам
- Тип: **Line Chart**
- Ось X: `Orders[Order YearMonth]` (отсортировать по хронологии)
- Ось Y: мера `[Total Revenue]`
- Заголовок: "Динамика выручки по месяцам"
- Добавьте линию тренда: Analytics → Trend Line

#### График 2: Выручка по категориям
- Тип: **Bar Chart** (горизонтальный)
- Ось Y (категория): `Products[category]`
- Ось X (значение): `SUM(Order_Items[item_total])`
- Заголовок: "Выручка по категориям товаров"
- Цвета: задайте вручную для красоты

#### График 3: Заказы по каналам продаж
- Тип: **Donut Chart**
- Легенда: `Orders[sales_channel]`
- Значение: мера `[Total Orders]`
- Заголовок: "Доля заказов по каналу"

#### График 4: Заказы по способу оплаты
- Тип: **Treemap** или **Bar Chart**
- Категория: `Orders[payment_method]`
- Значение: `[Total Revenue]`

#### Фильтры (слева или вверху — Slicers):
- **Год**: `Orders[Order Year]` — тип: Dropdown
- **Статус заказа**: `Orders[order_status]` — тип: List
- **Канал продаж**: `Orders[sales_channel]` — тип: List

---

### 📄 Страница 2: Клиенты и сегментация (Customers)

**Назначение:** Кто наши покупатели, откуда они, как мы их привлекаем.

#### График 1: Клиенты по полу
- Тип: **Pie Chart**
- Легенда: `Customers[gender]`
- Значение: `DISTINCTCOUNT(Customers[customer_id])`
- Цвета: розовый для Female, голубой для Male

#### График 2: Клиенты по возрастным группам
- Тип: **Column Chart**
- Ось X: `Customers[age_group]` (упорядочить вручную: 18-24, 25-34, 35-44, 45-54, 55+)
- Ось Y: `DISTINCTCOUNT(Customers[customer_id])`
- Заголовок: "Распределение по возрасту"

#### График 3: Средний чек по каналу привлечения
- Тип: **Column Chart**
- Ось X: `Customers[acquisition_channel]`
- Ось Y: мера `[Avg Order Value]`
- Заголовок: "Средний чек по каналу привлечения"
- Добавьте метки данных

#### График 4: Топ-10 городов по числу клиентов
- Тип: **Bar Chart** (горизонтальный)
- Ось Y: `Customers[city]`
- Ось X: `DISTINCTCOUNT(Customers[customer_id])`
- Сортировка: по убыванию, Top 10

#### График 5: Топ-10 штатов по выручке
- Тип: **Map** (если включена геолокация) или **Bar Chart**
- Место: `Customers[state]`
- Значение: `[Total Revenue]`

#### Таблица: RFM-сегменты (вычисляемые в Power BI)
Создайте вычисляемый столбец для RFM-сегментов или импортируйте готовую таблицу из Python.
- Тип: **Matrix** или **Table**
- Строки: RFM-сегмент
- Колонки: Count, Avg Revenue, Avg Recency

#### Фильтры:
- **Пол**: `Customers[gender]`
- **Возрастная группа**: `Customers[age_group]`
- **Канал привлечения**: `Customers[acquisition_channel]`
- **Штат**: `Customers[state]`

---

### 📄 Страница 3: Продукты и качество (Products & Quality)

**Назначение:** Что продаётся, что возвращают, как оценивают.

#### График 1: Топ-10 товаров по выручке
- Тип: **Bar Chart** (горизонтальный)
- Ось Y: `Products[product_name]`
- Ось X: `SUM(Order_Items[item_total])`
- Фильтр Top N: 10 по значению
- Заголовок: "Топ-10 товаров по выручке"

#### График 2: Маржинальность по категориям
- Тип: **Column Chart**
- Ось X: `Products[category]`
- Ось Y: `AVERAGE(Products[margin_pct])` (margin_pct — вычисляемый столбец)
- Заголовок: "Средняя маржа по категориям (%)"

#### График 3: Причины возвратов
- Тип: **Bar Chart** или **Donut Chart**
- Категория: `Returns[return_reason]`
- Значение: `COUNTROWS(Returns)`
- Заголовок: "Топ причин возвратов"

#### График 4: Процент возвратов по категории
- Тип: **Column Chart**
- Ось X: `Products[category]`
- Ось Y: мера `[Return Rate]`
- Условное форматирование: красный если > 10%, зелёный если < 5%

#### График 5: Средний рейтинг по категориям
- Тип: **Bar Chart** (горизонтальный)
- Ось Y: `Products[category]`
- Ось X: мера `[Avg Rating]`
- Задайте диапазон оси: 0–5
- Добавьте метки данных
- Заголовок: "Средний рейтинг по категориям"

#### График 6: Распределение рейтингов (1-5 звёзд)
- Тип: **Column Chart**
- Ось X: `Reviews[rating]`
- Ось Y: `COUNTROWS(Reviews)`
- Цвета: градиент от красного (1) до зелёного (5)

#### Фильтры:
- **Категория**: `Products[category]`
- **Тип кожи**: `Products[skin_type]`
- **Статус возврата**: `Returns[refund_status]`
- **Год**: `Orders[Order Year]`

---

## Советы по оформлению

### Цветовая палитра
Для косметического бренда хорошо подходит:
- Основной цвет: #2E86AB (синий) или #7B9E87 (зелёный/природный)
- Акцент: #E84855 (красный) для негативных метрик (возвраты)
- Нейтральный: #F5F5F5 (светло-серый) для фона

### Типографика
- Заголовки страниц: 18-20pt, жирный
- Названия визуалов: 13-14pt
- Метки данных: 10-11pt

### Интерактивность
- Включите **Cross-filtering** между всеми визуалами на странице
- Добавьте **Tooltips** с дополнительными деталями
- Используйте **Bookmarks** для переключения между видами

---

## Какие выводы можно сделать по дашборду

1. **Overview → KPI карточки**: Мгновенный health check бизнеса — как дела сегодня?
2. **Overview → Линейный график**: Есть ли сезонность? Идёт ли рост?
3. **Customers → Канал привлечения**: Из какого канала приходят клиенты с лучшим чеком?
4. **Products → Возвраты**: Какая категория имеет критически высокий % возвратов?
5. **Products → Рейтинг**: Есть ли корреляция между низким рейтингом и высоким % возвратов?

---

*Примечание: Power BI Desktop бесплатен для скачивания на сайте Microsoft.*
