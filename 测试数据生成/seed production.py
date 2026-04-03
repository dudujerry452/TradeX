import os
import re
import json
from openai import OpenAI


BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SEED_FILE_PATH = os.path.join(BASE_DIR, "seed.py")
OUTPUT_FILE_PATH = os.path.join(BASE_DIR, "seed_final.py")

client = OpenAI(
    api_key="sk-78aaea842dc247b49d356f82b12e2e98", 
    base_url="https://api.deepseek.com"
)

# 预定义一套丰富的全局标签
MASTER_TAGS = [
    {"id": "tag_001", "name": "新品上市", "category": "营销"},
    {"id": "tag_002", "name": "热销爆款", "category": "营销"},
    {"id": "tag_003", "name": "高性价比", "category": "营销"},
    {"id": "tag_004", "name": "高端旗舰", "category": "营销"},
    {"id": "tag_005", "name": "苹果", "category": "品牌"},
    {"id": "tag_006", "name": "索尼", "category": "品牌"},
    {"id": "tag_007", "name": "电子产品", "category": "品类"},
    {"id": "tag_008", "name": "影音娱乐", "category": "品类"},
    {"id": "tag_009", "name": "办公必备", "category": "品类"},
    {"id": "tag_010", "name": "运动健康", "category": "品类"},
    {"id": "tag_011", "name": "智能家居", "category": "品类"},
    {"id": "tag_012", "name": "便携轻巧", "category": "特性"},
    {"id": "tag_013", "name": "超长续航", "category": "特性"},
    {"id": "tag_014", "name": "主动降噪", "category": "特性"},
    {"id": "tag_015", "name": "大容量", "category": "特性"},
]

def main():
    if not os.path.exists(SEED_FILE_PATH):
        print(f"❌ 找不到文件: {SEED_FILE_PATH}\n请确保在正确的文件夹中运行脚本！")
        return

    with open(SEED_FILE_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    print("🔍 正在提取产品信息...")
    # 用正则精准提取 product_id, product_name, category, description
    product_pattern = re.compile(
        r'product_id="([^"]+)",\s*product_name="([^"]+)",\s*category="([^"]+)",\s*description="([^"]+)"',
        re.S
    )
    
    products_info = []
    for match in product_pattern.finditer(content):
        pid, pname, pcat, pdesc = match.groups()
        products_info.append({
            "product_id": pid, "product_name": pname, 
            "category": pcat, "description": pdesc
        })

    print(f"✅ 共提取到 {len(products_info)} 个产品。开始分批调用 DeepSeek...")

    all_updates = []
    batch_size = 40 # 每批 40 个，完美避开 Token 截断
    
    for i in range(0, len(products_info), batch_size):
        chunk = products_info[i:i+batch_size]
        print(f"🚀 正在处理第 {i+1} 到 {min(i+batch_size, len(products_info))} 个产品...")
        
        prompt = f"""
        你是一个数据清洗专家。请分析以下产品 JSON 列表和全局标签库。
        
        任务：
        1. 【去重重命名】：检查 `product_name`，如果存在大量通用名称（如"便携式榨汁机"），请结合其 `description` 里的特征（如容量、颜色、材质），为它生成一个唯一的 `new_name`（例如"便携式榨汁机-304不锈钢版"）。
        2. 【打标签】：从全局标签库中，为每个产品挑选 2 到 3 个最贴切的 tag_id。
        
        全局标签库：
        {json.dumps(MASTER_TAGS, ensure_ascii=False)}
        
        本批次产品：
        {json.dumps(chunk, ensure_ascii=False)}
        
        【严格要求】：只返回合法的 JSON 数组，不要返回任何 markdown 标记（如 ```json）或说明文字。
        JSON 格式样例：
        [
          {{"product_id": "seed_prod001", "new_name": "苹果 iPhone 16 Pro", "tag_ids": ["tag_005", "tag_007", "tag_004"]}}
        ]
        """
        
        response = client.chat.completions.create(
            model="deepseek-chat",
            messages=[{"role": "system", "content": "You output only pure JSON arrays."},
                      {"role": "user", "content": prompt}],
            stream=False
        )
        
       
        raw_result = response.choices[0].message.content.strip()
        raw_result = re.sub(r'^```json|^```|```$', '', raw_result, flags=re.MULTILINE).strip()
        
        try:
            batch_updates = json.loads(raw_result)
            all_updates.extend(batch_updates)
        except json.JSONDecodeError as e:
            print(f"❌ JSON 解析失败，跳过此批次。原因: {e}")
            print(f"接口返回原文:\n{raw_result}")

    print("✨ API 处理完毕，正在本地重组 seed_final.py...")

    new_content = content
    product_tags_code = "PRODUCT_TAGS = [\n"
    pt_id = 1

    # 1. 替换产品名称并收集关联标签
    for update in all_updates:
        pid = update.get("product_id")
        new_name = update.get("new_name")
        tag_ids = update.get("tag_ids", [])
        
        if pid and new_name:
            # 使用正则安全地替换对应 product_id 的 product_name
            pattern = re.compile(rf'(product_id="{pid}",\s*product_name=")([^"]+)(")')
            new_content = pattern.sub(rf'\g<1>{new_name}\g<3>', new_content)
        
        for tid in tag_ids:
            product_tags_code += f'    dict(id={pt_id}, product_id="{pid}", tag_id="{tid}", weight=1.0),\n'
            pt_id += 1
            
    product_tags_code += "]\n"

    # 生成新的 TAGS 列表
    tags_code = "TAGS = [\n"
    for t in MASTER_TAGS:
        tags_code += f'    dict(tag_id="{t["id"]}", tag_name="{t["name"]}", category="{t["category"]}", usage_count=0),\n'
    tags_code += "]\n"

    # 替换原文件中的 TAGS 和 PRODUCT_TAGS 模块
    new_content = re.sub(r'TAGS\s*=\s*\[.*?\]\n', tags_code, new_content, flags=re.S)
    new_content = re.sub(r'PRODUCT_TAGS\s*=\s*\[.*?\]\n', product_tags_code, new_content, flags=re.S)

    # 4. 保存为新文件
    with open(OUTPUT_FILE_PATH, "w", encoding="utf-8") as f:
        f.write(new_content)

    print(f"🎉 大功告成！完美合并的文件已保存为: {OUTPUT_FILE_PATH}")
    print("你可以直接检查 seed_final.py，如果没有问题，用它替换原有的 seed.py 即可！")

if __name__ == "__main__":
    main()