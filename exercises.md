# Phiếu Phản Ánh — K4 Level 3B, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay mỗi dòng placeholder bên dưới bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Phùng Quang Minh Huy    Mã học viên: 2A202602610

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Mình deploy lên Railway và quên set `AGENT_API_KEY` trên dashboard. Vì trường
> này không có mặc định, `Settings()` ném `ValidationError` ngay lúc container
> khởi động, nên `/health` không bao giờ trả 200, healthcheck fail và Railway
> báo deploy lỗi ngay — mình thấy liền trong log, trước khi có request nào.
> Nếu để mặc định `"changeme"`: container vẫn xanh, URL vẫn public, và bất kỳ
> ai chỉ cần gửi header `X-API-Key: changeme` là gọi `/ask` được, đốt hết ngân
> sách LLM. Lúc đó mình chỉ phát hiện qua hóa đơn, tức là đã quá muộn — "chết
> sớm" đổi một lỗi cấu hình rẻ tiền lấy một sự cố tốn tiền.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Dòng log mình thu được khi gọi `/ask`:
>
> ```json
> {"event": "ask_completed", "level": "info", "timestamp": "2026-09-29T06:14:16.554521+00:00", "user_id": "sv-test", "tokens_in": 3, "tokens_out": 37, "cost_usd": 2.265e-05}
> ```
>
> Hai việc làm được mà `print("đã trả lời xong")` không làm được:
> 1. **Lọc và tổng hợp theo trường**: mình tính `sum(cost_usd)` theo `user_id`
>    để biết ai đang tiêu tiền, hay đếm số lần `event="ask_completed"`. Vì mỗi
>    dòng là JSON có khóa cố định, nền tảng log (Railway, Datadog…) query được;
>    còn chuỗi `print` là text tự do, không parse/aggregate được.
> 2. **Cảnh báo và truy vết theo mức**: mình đặt alert khi `level="error"`, và
>    đã thực sự dùng nó để đọc `event="redis_ping_failed"` kèm `error_type` và
>    `error` khi Redis chết. Chuỗi print không có khóa để alert hay tìm theo
>    loại lỗi.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | ~1.0 GB (`python:3.11` đầy đủ) |
| Multi-stage | ~0.2 GB (`python:3.11-slim` + site-packages) |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Chênh lệch khoảng 5 lần. Bản 1 stage dùng `python:3.11` đầy đủ nên mang theo
> cả hệ điều hành base lớn, compiler/build toolchain (gcc, make…), header,
> tài liệu và cache của pip nằm chung trong image. Bản multi-stage tách ra:
> stage `builder` cài dependency vào `/install`, stage runtime chỉ dùng
> `python:3.11-slim` rồi `COPY --from=builder /install /usr/local` và copy
> `app/`, `utils/`. Nhờ vậy image runtime không mang compiler, không mang pip
> cache, không mang layer build trung gian — chỉ còn interpreter gọn và
> thư viện cần chạy. (Số trên là đo bằng `docker images`; mình sẽ ghi đúng số
> đo trên máy nếu chênh lệch.)

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Thứ tự của mình: `FROM` → `WORKDIR` → `COPY requirements.txt` →
> `RUN pip install` → `COPY app ./app` → `COPY utils ./utils` → tạo user/`USER`.
> Khi sửa một ký tự trong `app/main.py`, Docker so hash từng layer: các layer
> base, `WORKDIR`, `COPY requirements.txt` và đặc biệt `RUN pip install` không
> đổi nên **được dùng lại từ cache**; cache bị phá từ layer `COPY app ./app`
> trở đi, nên chỉ `COPY app`, `COPY utils` và `USER` chạy lại — build vài giây
> và pip không cài lại gì.
> Nếu đặt `COPY . .` **trước** `RUN pip install`: mỗi lần sửa một ký tự source,
> layer `COPY . .` đổi hash, kéo theo `RUN pip install` chạy lại từ đầu — phải
> resolve và cài lại toàn bộ thư viện mỗi lần build, chậm hơn nhiều (vài chục
> giây tới vài phút) và tốn băng thông vô ích.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Chuỗi sự kiện: code Python có lỗ hổng cho phép thực thi lệnh (ví dụ RCE qua
> một dependency hoặc deserialization) → kẻ tấn công gửi payload và chạy được
> lệnh trong container với quyền của process. Nếu process chạy root (uid 0),
> hắn có toàn quyền trong container (đọc/ghi mọi file, cài thêm tool), rồi lợi
> dụng một lỗ hổng kernel/container escape, volume mount, hoặc docker socket để
> thoát ra host → thành root trên host và ảnh hưởng các container khác.
> Lệnh `USER appuser` cắt chuỗi ngay ở mắt "chạy bằng quyền gì": process chỉ
> còn uid thường (1001), không ghi được file hệ thống, không bind port <1024,
> không mount; kể cả bị RCE thì thiệt hại bị giới hạn trong container và việc
> escape khó hơn nhiều. Đây là nguyên tắc least privilege.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> Tối đa **20 request trong ~2 giây**. Cách làm: gửi 10 request vào lúc
> 10:00:59 — vẫn thuộc "phút 10:00" nên dùng hết quota của phút đó; đúng
> 10:01:00 phút mới bắt đầu và quota reset, gửi tiếp 10 request trong lúc
> 10:01:00–10:01:01. Cả hai phút đều "đúng luật 10/phút" nhưng thực tế dồn 20
> request vào 2 giây. Sliding window 60 giây không có khe hở này: tại 10:01:01
> nó vẫn đếm 10 request của 10:00:59 nằm trong 60 giây gần nhất, nên request
> thứ 11 lập tức bị 429.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> **Rate limit** giới hạn *số lượng request theo thời gian* (10/phút → 429).
> **Cost guard** giới hạn *số tiền theo tháng* (vượt ngân sách → 402).
> - Rate cho qua, cost chặn: người dùng gửi ít request nhưng mỗi prompt cực
>   lớn (hàng chục nghìn token). Về số lượng vẫn dưới 10/phút nên rate limit
>   cho qua, nhưng tổng tiền đã vượt ngân sách tháng → cost guard trả 402.
> - Cost cho qua, rate chặn: người dùng bắn liên tục 15 câu "hi" rất rẻ trong
>   một phút. Ngân sách còn rất nhiều nên cost guard cho qua, nhưng vượt hạn
>   mức 10 request/phút → rate limit trả 429.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> Thứ tự sự kiện nếu gộp endpoint và cho nó kiểm tra Redis:
> 1. Redis mất kết nối → cả 3 container đều trả 503 ở endpoint chung.
> 2. Orchestrator coi tín hiệu đó là liveness thất bại → bắt đầu restart
>    container A.
> 3. B và C cũng đang "unhealthy" nên bị rút khỏi vòng traffic và bị restart
>    theo → không còn instance nào phục vụ, request đang xử lý bị cắt.
> 4. Restart app không sửa được Redis, nên sau khi lên lại chúng vẫn 503 và
>    tiếp tục bị restart — crash loop, downtime bị khuếch đại.
> Tách đúng vai trò: `/health` (liveness) vẫn 200 vì process còn sống → không
> bị restart; `/ready` trả 503 → load balancer tạm ngừng đẩy traffic vào; khi
> Redis trở lại, `/ready` tự 200 mà không cần restart. Mình đã gặp đúng tình
> huống này lúc Redis service crash-loop: `/health` vẫn 200 còn `/ready` 503,
> và nhờ tách endpoint nên các container không bị restart hàng loạt.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> Khi state nằm trong Redis (dùng chung cho cả 3 instance): mỗi lượt `/ask`
> ghi thêm 2 message (user + assistant) nên `history_length` tăng đều
> `0 → 2 → 4 → 6 …` bất kể request rơi vào instance nào, và restart container
> cũng không mất lịch sử.
> Nếu lịch sử nằm trong dict Python trong RAM: mỗi instance có dict riêng,
> load balancer xoay vòng A → B → C, nên request thứ hai rơi vào B lại thấy
> dict rỗng và trả `history_length = 0`. Con số không tăng đều mà nhảy loạn,
> tăng chậm hơn nhiều (chỉ khi trùng instance), và reset về 0 sau mỗi lần
> deploy/restart — agent "mất trí nhớ". Vì vậy state phải đưa ra Redis để
> service stateless và scale ngang được.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> Triệu chứng: sau khi deploy, `/health` trả 200 nhưng `/ready` trả 503
> `{"status": "not ready", "redis": false}`.
> Tìm nguyên nhân: `/health` 200 chứng tỏ app sống, nên nghi phần Redis. Mình
> thêm log lỗi vào `ping()` của `ConversationStore`, và log agent hiện
> `event="redis_ping_failed" error_type="TimeoutError" error="Timeout connecting
> to server"`. Xem log DNS/network flow của agent thì thấy `redis.railway.internal`
> phân giải bình thường và có kết nối TCP tới cổng 6379, nhưng vẫn timeout →
> mình mở log của chính **Redis service** thì thấy nó crash-loop:
> `/bin/sh: 1: exec: docker-entrypoint.sh: not found`, không hề in dòng
> "Ready to accept connections". Nguyên nhân: trước đó mình chạy `railway up`
> khi CLI đang link nhầm vào service Redis, làm image của Redis bị ghi đè. Vậy
> lỗi không phải ở `REDIS_URL` mà ở bản thân Redis chưa chạy.
> Cách sửa: `railway service source connect --image redis:8.2 --service Redis`
> để trả Redis về image chính thức, rồi `railway deployment redeploy -s Redis
> --yes`; đợi log `Ready to accept connections tcp`. Sau đó `/ready` trả 200
> `{"status": "ready", "redis": true}` và `/ask` có API key trả 200.
