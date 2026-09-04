# -*- coding: utf-8 -*-
"""
Build chunk_0633_0647.csv from manually transcribed dictionary pages
(PDF page indices 633-647, printed pages 1398-1412).
"""
import csv

# Each tuple: (printed_page, word, meaning_vi)
entries = [
# ---- page 1398 (idx0633) ----
(1398, "BATS (ballistic aerial target system)", "tổ hợp mục tiêu tên lửa đạn đạo trên không"),
(1398, "BATS (battle area tactical scenario)", "phương án xử trí tình huống chiến thuật khu vực chiến đấu; phương án xử trí tình huống (chiến đấu) trong khu vực phòng ngự"),
(1398, "BATS (battle area tactical simulation)", "sự mô phỏng tình huống chiến thuật khu vực chiến đấu; sự mô phỏng tình huống (chiến đấu) trong khu vực phòng ngự"),
(1398, "BATT (battalion army training test)", "kiểm tra huấn luyện tiểu đoàn lục quân"),
(1398, "BB (Bailey bridge)", "cầu lắp ghép bằng kim loại Beli, cầu thép cơ động Beli, cầu Beli"),
(1398, "BB (bomb)", "bom"),
(1398, "BB (breakbulk)", "hàng hoá quá cỡ"),
(1398, "BB (base bleed)", "trích khí đáy (đạn)"),
(1398, "BB (base burn)", "phụt lửa đáy (đạn)"),
(1398, "BB (battleship)", "tàu chủ lực, thiết giáp hạm"),
(1398, "BB (blowback)", "(vận hành bằng) luồng hơi phụt hậu"),
(1398, "BBC (broad-band chaff)", "nhiễu (tiêu cực) băng tần rộng"),
(1398, "BBC (built-in ballistic computer)", "máy tính đường đạn lắp liền, máy tính thuật phóng lắp liền"),
(1398, "BBE (bridge boat erection)", "dựng cầu phao"),
(1398, "BBGT (brigade & battle group trainer)", "thiết bị huấn luyện lữ đoàn và chiến đoàn"),
(1398, "BBH (battalion beachhead)", "vị trí đầu cầu đổ bộ (đường biển) của tiểu đoàn, khu vực đổ quân của tiểu đoàn; bãi đổ quân đổ bộ (đường biển) của tiểu đoàn"),
(1398, "Bbr (bomber)", "máy bay ném bom, máy bay cường kích"),
(1398, "BBS (brigade & battalion simulation)", "thiết bị mô phỏng cấp lữ đoàn và tiểu đoàn (tình huống chiến đấu)"),
(1398, "BBU (base bleed unit)", "khối trích khí đáy (đạn)"),
(1398, "BC (battery commander)", "đại đội trưởng pháo binh; (Mỹ) khẩu đội trưởng pháo binh"),
(1398, "BC (Bomber Command)", "bộ tư lệnh không quân ném bom, bộ chỉ huy máy bay ném bom"),
(1398, "BC/WC (ballistic computer/weapon controller)", "máy tính đường đạn / bộ điều khiển vũ khí"),
(1398, "BCA (buoyant cable antenna)", "anten cáp phao (nổi)"),
(1398, "BCAR (British Civil Airworthiness Requirements)", "(Anh) các quy tắc tính khả phi của hàng không dân dụng, quy tắc chuẩn bị bay của hàng không dân dụng"),
(1398, "BCAT (beddown capability assessment tool)", "công cụ đánh giá khả năng trú quân"),
(1398, "BCAU (backup control & audio unit)", "khối điều khiển và truyền thanh dự phòng"),
(1398, "BCB (broadband communication bus)", "tuyến thông tin liên lạc băng tần rộng"),
(1398, "BCC (battery control centre)", "trung tâm chỉ huy đại đội pháo binh"),
(1398, "BCD (battlefield coordination detachment)", "đội hiệp đồng tác chiến trên chiến trường"),
(1398, "BCD (binary coded decimal)", "số thập phân mã hóa nhị phân"),
(1398, "BCE (battlefield control element)", "thành phần chỉ huy chiến trường, bộ phận chỉ huy chiến trường"),
(1398, "Bcl Msgr (bicycle messenger)", "liên lạc viên đi xe đạp"),
(1398, "BCM (basic combat maneuvering)", "cơ động chiến đấu cơ bản"),
(1398, "BCN (beacon)", "đèn biển; tín hiệu hỗ trợ định hướng"),
(1398, "BCN (beacon radar mode)", "chế độ móc rađa"),
(1398, "BCOC (base cluster operations center)", "trung tâm chỉ huy tác chiến cụm căn cứ"),
(1398, "BCP (battery command post)", "đài chỉ huy đại đội pháo binh"),
(1398, "BCR (baseline change request)", "yêu cầu thay đổi tuyến cơ sở"),
(1398, "BCR (bomblets cargo round)", "đạn mang đạn con, đạn mẹ"),

# ---- page 1399 (idx0634) ----
(1399, "BCS (ballistic computer system)", "tổ hợp máy tính đường đạn"),
(1399, "BCS (battery computer system)", "tổ hợp máy tính phần tử bắn của đại đội pháo binh"),
(1399, "BCST (broadcast)", "phát thanh"),
(1399, "BCT (basic combat training)", "khoá huấn luyện chiến đấu cơ bản; sự huấn luyện chiến đấu cơ bản"),
(1399, "BCT (battlefield command terminal)", "trạm thông tin liên lạc đầu cuối của bộ tư lệnh mặt trận"),
(1399, "BCT (battlefield command trainer)", "thiết bị huấn luyện chỉ huy (cấp) chiến thuật"),
(1399, "BCT (Brigade Combat Team)", "(US) đội chiến đấu thuộc lữ đoàn (Mỹ); đội chiến đấu cấp lữ đoàn"),
(1399, "BCTP (battle command training program)", "chương trình huấn luyện chỉ huy chiến đấu"),
(1399, "BCU (battery computer unit)", "khối máy tính phần tử bắn của đại đội pháo binh"),
(1399, "BCU (beach clearance unit)", "đơn vị phá gỡ vật cản bãi đổ bộ đường biển"),
(1399, "BCV (Battle Command Vehicle)", "xe chỉ huy chiến đấu; tàu chỉ huy chiến đấu; máy bay chỉ huy chiến đấu"),
(1399, "BCW (binary chemical warhead)", "đầu đạn hóa học hai thành phần"),
(1399, "BD (base detonating)", "ngòi nổ đáy, ngòi đáy; kích nổ đáy"),
(1399, "BD (battle dress)", "quân phục dã chiến, quân phục chiến đấu"),
(1399, "Bd (boundary)", "đường biên giới, ranh giới"),
(1399, "BDA (battle damage assessment)", "sự đánh giá tổn thất chiến đấu"),
(1399, "BDA (bomb damage assessment)", "sự đánh giá kết quả ném bom"),
(1399, "BDAR (battle damage assessment and repair)", "sự đánh giá thiệt hại và sửa chữa tại chiến trường"),
(1399, "BDC (bottom dead center)", "điểm chết dưới"),
(1399, "Bde; BDE (brigade)", "lữ đoàn"),
(1399, "bde avn plat (brigade aviation platoon)", "trung đội không quân của lữ đoàn"),
(1399, "Bde Maj (brigade major)", "(Anh) trưởng ban trinh sát - tác chiến lữ đoàn"),
(1399, "BDGT (budget)", "ngân sách"),
(1399, "BDL (beach discharge lighter)", "đèn chiếu sáng bãi đổ bộ"),
(1399, "BDM (ballistic defense missile)", "tên lửa đánh chặn tên lửa đạn đạo"),
(1399, "BDOC (base defense operations center)", "trung tâm chỉ huy tác chiến phòng thủ căn cứ"),
(1399, "BDR (battle damage repair)", "sửa chữa hư hỏng trong chiến đấu (vũ khí trang bị)"),
(1399, "Bdr (bombardier)", "nhân viên cắt bom; thiết bị cắt bom (trên máy bay)"),
(1399, "bdry; bdy (boundary)", "đường biên giới, ranh giới"),
(1399, "BDU (battle dress uniform)", "quân phục chiến đấu"),
(1399, "BDV (breakdown voltage)", "hiệu điện thế đánh thủng"),
(1399, "BDZ (base defense zone)", "khu vực phòng thủ căn cứ"),
(1399, "BE (base ejection)", "sự phụt khí qua đáy đạn"),
(1399, "BE (basic encyclopedia)", "bản tổng hợp dữ liệu cơ bản"),
(1399, "BE (Belgium)", "Bỉ"),
(1399, "BE-12 (Soviet amphibious patrol aircraft)", "thuỷ phi cơ tuần tiễu Liên Xô BE-12"),
(1399, "BEES (basic ECM environment simulator)", "thiết bị cơ bản (để) mô phỏng trang bị kỹ thuật bảo đảm chống tác chiến điện tử"),
(1399, "BEF (British Expeditionary Force)", "lực lượng viễn chinh Anh"),
(1399, "BEN (base encyclopedia number)", "số lượng tổng hợp dữ liệu cơ sở"),
(1399, "BER (bit error ratio)", "tỉ lệ sai số bit"),
(1399, "BET (best estimated trajectory)", "quỹ đạo (bay) tính toán tối ưu"),
(1399, "BETA (battlefield exploitation & target acquisition)", "(thiết bị) sục sạo và bắt bám mục tiêu chiến thuật"),

# ---- page 1400 (idx0635) ----
(1400, "BF (base fuzed)", "kích nổ đáy đạn"),
(1400, "BF (British Forces)", "lực lượng vũ trang Anh, lực lượng quân sự Anh"),
(1400, "BFA (blank firing attachment)", "dụng cụ để bắn đạn giả của súng liên thanh"),
(1400, "BFD (bearing/frequency display)", "sự hiển thị phương vị / tần số (trên màn hình)"),
(1400, "BFDC (battalion fire distribution center)", "trung tâm phân chia hoả lực tiểu đoàn"),
(1400, "BFPO (British Forces Post Office)", "cục bưu điện quân đội Anh, ngành quân bưu Anh"),
(1400, "BFTA (bulk fuel tank assembly)", "thùng nhiên liệu chính"),
(1400, "BFV (Bratley fighting vehicle)", "xe chiến đấu Brátlây"),
(1400, "BFVS (Bradley fighting vehicle system)", "hệ thống xe chiến đấu Brátlây"),
(1400, "BG (battle group)", "chiến đoàn; cụm chiến đấu"),
(1400, "BG (beach group)", "nhóm bờ biển, nhóm bảo đảm đổ bộ, nhóm phục vụ khu vực đổ bộ đường biển"),
(1400, "BG (brigadier general)", "chuẩn tướng"),
(1400, "BGC (boat group commander)", "tư lệnh (trưởng) cụm phương tiện đổ bộ (đường biển)"),
(1400, "BGLT (battle group landing team)", "nhóm dọn bãi của chiến đoàn đổ bộ, nhóm chiếm giữ khu vực đổ bộ"),
(1400, "bgr (bombing and gunnery range)", "tầm bắn và ném bom"),
(1400, "BHD; bhd (beachhead)", "căn cứ đầu cầu đổ bộ, vị trí đầu cầu đổ bộ, vị trí bàn đạp đổ bộ, bãi đổ quân đổ bộ đường biển"),
(1400, "Bhd (bulkhead)", "vách ngăn (tàu)"),
(1400, "BHP (brake horse power)", "công suất hãm (tính bằng mã lực)"),
(1400, "BI (battle injury)", "thương tích trong chiến đấu; bị thương trong chiến đấu"),
(1400, "BIA (Bureau of Indian Affairs)", "cục các vấn đề về người Anhđiêng"),
(1400, "BIAS (Battlefield Illumination Assistance System)", "hệ thống hỗ trợ chiếu sáng chiến trường"),
(1400, "BIB (baby incendiary bomb)", "bom cháy cỡ nhỏ"),
(1400, "BIDDS (Base Information Digital Distribution System)", "hệ thống phân phối thông tin kỹ thuật số cơ sở"),
(1400, "BIDE (basic identity data element)", "thành phần dữ liệu nhận diện cơ bản"),
(1400, "BIII (International Time Bureau (Bureau International d'l'Heure))", "văn phòng về giờ quốc tế"),
(1400, "BIO; biol (biological)", "(thuộc) sinh học"),
(1400, "biol agt (biological agent)", "chất độc sinh học"),
(1400, "BIOLDEF (biological defense)", "phòng chống sinh học"),
(1400, "BIOLOP (biological operations)", "sự sử dụng vũ khí sinh học; tác chiến bằng vũ khí sinh học"),
(1400, "BIOLWPN (biological weapons)", "vũ khí sinh học; phương tiện chiến tranh sinh học"),
(1400, "BIOLWPNSYS (biological weapon system)", "hệ thống vũ khí sinh học, tổ hợp các phương tiện chiến tranh sinh học"),
(1400, "biowar (biological warfare)", "chiến tranh sinh học; tác chiến sinh học"),
(1400, "BIRADS (bistatic receiver and display system)", "tổ hợp thu và hiển thị (trên màn hình) hai trạm"),
(1400, "BISS (base installation security system)", "hệ thống bảo đảm an toàn kho tàng trong căn cứ"),
(1400, "BIST (built-in self test)", "tự đo kiểm bằng dụng cụ lắp liền (trên máy)"),
(1400, "BIT (built-in test)", "đo kiểm bằng dụng cụ lắp liền (trên máy)"),
(1400, "BITE (built-in test equipment)", "thiết bị đo kiểm lắp liền trên máy bay; thiết bị đo kiểm đi kèm"),
(1400, "BIU (beach interface unit)", "đơn vị phân giới khu vực đổ bộ đường biển"),
(1400, "biv (bivouac)", "trại dã chiến, khu vực bố trí dã chiến, nơi đóng quân dã chiến"),
]

# NOTE: continued in build_chunk_0633_0647_part2.py (imported below)
from build_chunk_0633_0647_part2 import entries as entries2
from build_chunk_0633_0647_part3 import entries as entries3
entries.extend(entries2)
entries.extend(entries3)

fieldnames = ["source_page","dictionary_name","word","phonetic","part_of_speech_raw",
              "part_of_speech_code","meaning_vi","is_subentry","example_en","example_vi",
              "image_path","reviewed"]

out_path = r"c:\Users\anhnt\Desktop\csb-vocab-app\docs\db\import\tudien_abbr_chunks\chunk_0633_0647.csv"
with open(out_path, "w", newline="", encoding="utf-8-sig") as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    for page, word, meaning in entries:
        writer.writerow({
            "source_page": page,
            "dictionary_name": "Military Dictionary",
            "word": word,
            "phonetic": "",
            "part_of_speech_raw": "",
            "part_of_speech_code": "",
            "meaning_vi": meaning,
            "is_subentry": "FALSE",
            "example_en": "",
            "example_vi": "",
            "image_path": f"img_{page}.jpg",
            "reviewed": "FALSE",
        })

print(f"Wrote {len(entries)} entries to {out_path}")
