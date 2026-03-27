你是一个专业开发助手, 现在数据库有如下改动: 

[changes]

你需要按顺序检查以下文件或模块并更新, 并遵循原有的代码风格, 坚定最小化改动: 

doc/ER图.md 更新ER图描述

backend/core/models.py 更新模型文件

backend/core/api.py 更新后端API

backend/core/tests.py 更新后端API测试

backend/core/management/commands/seed.py 更新数据库测试用例

然后更新数据库: 

rm backend/db.sqlite3

rm backend/core/migrations/0001_initial.py

然后执行: 

生成迁移文件 :`python3 backend/manage.py makemigrations` 
数据库迁移 :`python3 backend/manage.py migrate` 
插入seed数据 :`python3 backend/manage.py seed` 

最后, 
如果前端API有修改, 请输出. 




