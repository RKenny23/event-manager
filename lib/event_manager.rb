require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

puts 'EventManager initialized!'

contents = CSV.open(
  'event_attendees.csv', 
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  phone_number.gsub!(/[^\d]/,'')
  
  if phone_number.length == 10
    phone_number
  elsif phone_number.length < 10 || phone_number.length > 11
    phone_number = nil
  elsif phone_number.length == 11 && phone_number[0] == "1"
    phone_number.slice(1..10)
  end
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
  
  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

peak_hours_hash = Hash.new(0)
peak_days_hash = Hash.new(0)

def update_peak_hours_hash(datetime, peak_hours_hash)
  reg_hours = datetime.hour
  peak_hours_hash[reg_hours] += 1
end

def find_peak_hours(peak_hours_hash)
  peak_hours_hash.max_by {|k,v| v}
end

def update_peak_days_hash(datetime, peak_days_hash)
  reg_days = datetime.wday
  peak_days_hash[reg_days] += 1
end

def find_peak_days(peak_days_hash)
  peak_days_hash.max_by {|k,v| v}
  return Date::DAYNAMES[peak_days_hash.keys[0]]
end

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  raw_number = row[:homephone]
  clean_number = clean_phone_number(raw_number)
  # puts clean_number
  regdate = row[:regdate]
  datetime = DateTime.strptime(regdate,"%m/%d/%y %H:%M")
  
  update_peak_hours_hash(datetime, peak_hours_hash)
  update_peak_days_hash(datetime, peak_days_hash)
  
  legislators = legislators_by_zipcode(zipcode) 
  
  form_letter = erb_template.result(binding)
  
  save_thank_you_letter(id,form_letter)   
  
end

peak_hour = find_peak_hours(peak_hours_hash)
peak_day = find_peak_days(peak_days_hash)

puts "Peak registration hour is #{peak_hour[0]}:00. (#{peak_hour[1]} times)"
puts "Peak registration day is #{peak_day}. (#{peak_days_hash.values[0]} times)"
