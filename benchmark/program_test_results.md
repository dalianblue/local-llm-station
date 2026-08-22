# program_test.md 编程卷结果（temperature=0.0，思考关闭，实际运行验证）

## P1 ✅运行成功 （32.7s）

**代码**：

```python
import io
import pandas as pd

csv_data = """日期,销售额,成本,地区
2024-01,100,80,北区
2024-02,NaN,75,北区
2024-03,130,90,南区
2024-04,NaN,NaN,南区"""

df = pd.read_csv(io.StringIO(csv_data))

df['销售额'] = df['销售额'].ffill()
df['成本'] = df['成本'].fillna(df['成本'].mean())

df['利润率'] = (df['销售额'] - df['成本']) / df['销售额']

print(df)

```

**stdout**：

```
        日期    销售额         成本  地区       利润率
0  2024-01  100.0  80.000000  北区  0.200000
1  2024-02  100.0  75.000000  北区  0.250000
2  2024-03  130.0  90.000000  南区  0.307692
3  2024-04  130.0  81.666667  南区  0.371795

```

**stderr**：

```

```

## P2 ✅运行成功 （58.8s）

**代码**：

```python
import io
import pandas as pd
import numpy as np

csv_data = """日期,销售额,成本,地区
2024-01,100,80,北区
2024-02,NaN,75,北区
2024-03,130,90,南区
2024-04,NaN,NaN,南区"""

df = pd.read_csv(io.StringIO(csv_data))

# 前向填充销售额，均值填充成本
df['销售额'] = df['销售额'].ffill()
df['成本'] = df['成本'].fillna(df['成本'].mean())

# 1. 按地区分组计算销售额的均值、中位数、标准差
grouped_stats = df.groupby('地区')['销售额'].agg(['mean', 'median', 'std'])
print("1. 按地区分组的销售额统计：")
print(grouped_stats)

# 2. 计算每月利润率，再按地区求平均利润率
df['利润率'] = (df['销售额'] - df['成本']) / df['销售额']
avg_profit_rate = df.groupby('地区')['利润率'].mean()
best_region = avg_profit_rate.idxmax()
best_rate = avg_profit_rate.max()
print(f"\n2. 平均利润率最高的地区：{best_region}，平均利润率为：{best_rate:.4f}")

```

**stdout**：

```
1. 按地区分组的销售额统计：
     mean  median  std
地区                    
北区  100.0   100.0  0.0
南区  130.0   130.0  0.0

2. 平均利润率最高的地区：南区，平均利润率为：0.3397

```

**stderr**：

```

```

## P3 ✅运行成功 （42.3s）

**代码**：

```python
import numpy as np
import matplotlib.pyplot as plt
from scipy.stats import gaussian_kde

np.random.seed(0)
d = np.random.normal(170, 10, 200)

plt.figure()
plt.hist(d, bins=20, density=True, alpha=0.6, color='steelblue', label='Histogram')

kde = gaussian_kde(d)
x = np.linspace(d.min() - 20, d.max() + 20, 300)
plt.plot(x, kde(x), 'b-', linewidth=2, label='KDE')

plt.axvline(np.mean(d), color='red', linestyle='--', linewidth=2, label=f'Mean = {np.mean(d):.2f}')

plt.xlabel('Height')
plt.ylabel('Density')
plt.title('Height Distribution with KDE')
plt.legend()
plt.savefig('P3.png')
plt.show()

```

**stdout**：

```

```

**stderr**：

```
/private/tmp/qwen_prog_test/P3.py:22: UserWarning: FigureCanvasAgg is non-interactive, and thus cannot be shown
  plt.show()

```

## P4 ✅运行成功 （42.5s）

**代码**：

```python
import numpy as np
import matplotlib.pyplot as plt

np.random.seed(42)
categories = ['A', 'B', 'C', 'D']
values = [23, 45, 38, 52]

# Create gradient colors from light blue to dark blue
colors = plt.cm.Blues(np.linspace(0.3, 0.9, len(values)))

fig, ax = plt.subplots()
bars = ax.bar(categories, values, color=colors)

# Annotate each bar with its value
for bar, val in zip(bars, values):
    ax.text(bar.get_x() + bar.get_width() / 2., bar.get_height() + 1,
            str(val), ha='center', va='bottom', fontsize=12)

# Remove top and right spines
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)

plt.tight_layout()
plt.savefig('P4.png')
plt.close()

```

**stdout**：

```

```

**stderr**：

```

```

## P5 ✅运行成功 （37.8s）

**代码**：

```python
import numpy as np
import matplotlib.pyplot as plt
from scipy.stats import linregress

np.random.seed(123)
x = np.random.rand(50) * 100
y = 2.5 * x + np.random.randn(50) * 30

slope, intercept, r_value, p_value, std_err = linregress(x, y)
r_squared = r_value ** 2

plt.figure()
plt.scatter(x, y, label='Data')
plt.plot(x, slope * x + intercept, color='red', label=f'Fit: y={slope:.2f}x+{intercept:.2f}, R²={r_squared:.4f}')
plt.xlabel('x')
plt.ylabel('y')
plt.legend()
plt.savefig('P5.png')
plt.show()

```

**stdout**：

```

```

**stderr**：

```
/private/tmp/qwen_prog_test/P5.py:19: UserWarning: FigureCanvasAgg is non-interactive, and thus cannot be shown
  plt.show()

```

## P6 ✅运行成功 （59.6s）

**代码**：

```python
import pandas as pd
import matplotlib.pyplot as plt


def plot_summary(data, title):
    """
    绘制DataFrame中所有数值列的箱线图
    
    参数:
        data: pandas DataFrame
        title: 图表标题
    """
    numeric_cols = data.select_dtypes(include=['number']).columns.tolist()
    
    if not numeric_cols:
        raise ValueError("DataFrame中没有数值列")
    
    fig, ax = plt.subplots(figsize=(10, 6))
    data[numeric_cols].boxplot(ax=ax)
    ax.set_title(title)
    ax.set_ylabel('Value')
    plt.xticks(rotation=45, ha='right')
    plt.tight_layout()
    plt.savefig('P6.png', dpi=150, bbox_inches='tight')
    plt.close()


if __name__ == "__main__":
    # 生成示例数据
    import numpy as np
    
    np.random.seed(42)
    n = 100
    sample_data = pd.DataFrame({
        'A': np.random.normal(50, 10, n),
        'B': np.random.exponential(20, n),
        'C': np.random.uniform(0, 100, n),
        'D': np.random.randint(1, 100, n)
    })
    
    plot_summary(sample_data, "Summary Box Plot")

```

**stdout**：

```

```

**stderr**：

```

```

## P7 ✅运行成功 （21.8s）

**代码**：

```python
import matplotlib.pyplot as plt

labels = ['A', 'B', 'C']
sizes = [30, 45, 25]

plt.figure(figsize=(8, 6))
plt.pie(sizes, labels=labels, autopct='%1.1f%%', startangle=90)
plt.title('Pie Chart of A, B, C')
plt.axis('equal')
plt.savefig('P7.png')
plt.show()

```

**stdout**：

```

```

**stderr**：

```
/private/tmp/qwen_prog_test/P7.py:11: UserWarning: FigureCanvasAgg is non-interactive, and thus cannot be shown
  plt.show()

```
