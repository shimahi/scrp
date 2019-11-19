require 'net/http'
require 'uri'
require 'json'
require 'csv'
# require 'date'
# nowMonth = Date.today.strftime("%Y%m")

CSV.open('list.csv', 'w') do |csv|
  csv << ["ID", "マンション名", "住所", "最寄駅", "#最寄駅から徒歩何分", "階数", "単位面積", "最小価格", "最高価格", "築年数"]
end

AREAS = ["愛知県岡崎市", "愛知県刈谷市", "愛知県安城市", "愛知県知立市", "愛知県豊田市"]

NORTHMAX = 35.2908290000000
NORTHMIN = 34.8603050000000
EASTMAX = 137.5807640000000
EASTMIN = 136.9737460000000

$latDiff = (NORTHMAX - NORTHMIN) / 100 #緯度差の100分の一
$lonDiff = (EASTMAX - EASTMIN) / 100 #経度差の100分の一

# 1ブロックの左下
sw_latitude = NORTHMIN
sw_longitude = EASTMIN


#1ブロックあたりのCSV書き込み処理
def write_csv_data(sw_latitude, sw_longitude)

  #URIの取得
  uri = URI.parse("https://GマップAPIつこうてるやつ?geo_sw=#{sw_latitude}%2C#{sw_longitude}&geo_ne=#{sw_latitude + $latDiff}%2C#{sw_longitude + $lonDiff}")

  #レスポンスの存在を調べる
  json = Net::HTTP.get(uri)
  result = JSON.parse(json)
  if result
    targets = result["result"]["row_set"]
  else
    p "500: INTERNAL SERVER ERROR"
    return
  end

  targets.each do |target|

    full_address = target["full_address"] # 住所

    #住所から、物件がエリアに含まれるかどうかか調べる
    mapRes = AREAS.map do |area|
      full_address.include?(area)
    end
    next if !mapRes.any?

    building_id = target["building_id"] # ID
    building_name = target["building_name"] # マンション名
    floor_count = target["floor_count"] # 階数
    assessed_mode_unit_area_rent = target["assessed_mode_unit_area_rent"] # 単位面積
    year_built = target["year_built"] # 築年数

    #最寄駅情報の取得
    station_name = nil
    walk_minutes = nil
    if target["near_stations"]
      if target["near_stations"][0]
        station_name = target["near_stations"][0]["station_name"] #最寄駅
        walk_minutes = target["near_stations"][0]["walk_minutes"] #最寄駅から徒歩何分
      end
    end

    # 価格の取得
    rooms_uri = URI.parse("https://www.homes.co.jp/price-map/api/dwelling_units?building_id=#{building_id}&offset=0&display_price_status=1&display_price_status_rent=1&display_price_status_operator=or")
    rooms_json = Net::HTTP.get(rooms_uri)
    rooms_result = JSON.parse(rooms_json)

    if rooms_json

      min_prices = rooms_result["result"]["row_set"].map do |room|
        room["assessed_min_price"]
      end.compact

      if min_prices
        min_price = min_prices.min
      end

      max_prices = result["result"]["row_set"].map do |room|
        room["assessed_max_price"]
      end.compact

      if max_prices
        max_price = max_prices.max
      end

    else
      min_price = nil
      max_price = nil
    end

    # CSV書き込み
    CSV.open('list.csv', 'a') do |csv|
      csv << [building_id, building_name, full_address, station_name, walk_minutes, floor_count, assessed_mode_unit_area_rent, min_price, max_price, year_built]
    end

  end
end


# ループ処理
eastCount = 1
northCount = 1
while sw_latitude < NORTHMAX

  while sw_longitude < EASTMAX
    #CSV書き込み処理
    write_csv_data(sw_latitude, sw_longitude)
    p "北:#{northCount},東:#{eastCount}"
    sw_longitude += $lonDiff
    eastCount += 1;
  end

  northCount += 1;
  sw_latitude += $latDiff

  sw_longitude = EASTMIN
  eastCount = 1
end
