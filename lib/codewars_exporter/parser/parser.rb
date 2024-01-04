# frozen_string_literal: true

require 'watir'
require 'nokogiri'
require 'fileutils'
require './lib/codewars_exporter/api/profile'
require_relative 'nickname_parser'

class Parser
  DATA_FILE = '.data'
  SOLUTION_FILE = 'solution.txt'
  SOLUTION_PATH = "solutions/#{@language}"
  LOGIN_URL = 'https://www.codewars.com/users/sign_in'

  attr_accessor :browser, :email, :password

  def initialize(email=nil, password=nil)
    @email = email
    @password = password
  end

  def run
    request_login_pass
    find_nick

    choice_how_save
    choice_language

    login
    choose_separate_save

    puts 'Work completed! Closing browser...'
    @browser.close
  end

  protected

  def find_nick
    puts 'login to codewars and them parse your nickname...'
    sleep(3)

    parser = NicknameParser.new(@email, @password)
    parser.run
    @nickname = parser.username
  end

  def solution_url
    "https://www.codewars.com/users/#{@nickname}/completed_solutions"
  end

  def choose_separate_save
    puts 'Start parsing solutions!'
    if @choice_save == 1
      parse.separate_data.place_by_files
      puts "#{SOLUTION_PATH} was created! closing program..."
    else
      parse.separate_data.place_to_one_file
      puts "'#{SOLUTION_FILE}' was created! closing program..."
    end
  end

  def choice_how_save
    puts "Choose how's save files"

    puts '1) Save every solution to every file'
    puts '2) Save all solutions to one file'

    @choice_save = $stdin.gets.chomp.to_i

    puts(@choice_save == 1 ? 'solutions to every file' : 'solutions to one file')
  end

  def choice_language
    profile = Api::Profile.new(@nickname)

    puts 'choose the language which need to parse?'
    puts "I am detected these languages: #{profile.languages.join(', ')}"

    @language = $stdin.gets.chomp.to_s.downcase

    puts "okay, your choise is #{@language}"
  end

  def request_login_pass
    puts 'Starting request data...'

    if email.nil? || password.nil?
      puts 'Enter your email:'
      @email = gets.chomp

      puts 'Enter your password:'
      @password = gets.chomp
    else
      puts 'We already have data, skipping stage'
    end
  end

  def start_browser
    @browser = Watir::Browser.new :firefox, headless: true
  end

  def login
    puts 'login to codewars and them start parse, get some coffee if you have a lot of solutions'
    sleep(3)

    start_browser
    @browser.goto(LOGIN_URL)

    @browser.text_field(id: 'user_email').set(email)
    @browser.text_field(id: 'user_password').set(password)
    @browser.button(type: 'submit').click

    @browser
  end

  def parse
    @browser.goto(solution_url)
    browser = scroll_to_bottom_page(@browser)

    doc = Nokogiri::HTML.parse(browser.html)
    @data = doc.css('.list-item-solutions')

    puts 'parsing complete!'
    @browser.close

    self
  end

  def separate_data
    @data = @data.select {|item| item.at('code')['data-language'] == @language }
                 .map {|item|
      {
        solution_name: item.at_css('a').text,
        kyu:           item.at_css('.inner-small-hex').text,
        solution:      item.at_css('pre').text
      }
    }

    self
  end

  def place_by_files
    FileUtils.mkdir_p(SOLUTION_PATH)

    @data.each do |n|
      name_kyu = "#{n[:solution_name]} #{n[:kyu]}"

      File.open(File.join(SOLUTION_PATH, name_kyu), 'w') do |file|
        file.write(n[:solution])
      end

      puts name_kyu
    end
  end

  def place_to_one_file
    @data.each do |n|
      File.write(SOLUTION_FILE, "#{n[:solution_name]} #{n[:kyu]}\n", mode: 'a')

      File.write(SOLUTION_FILE, "#{n[:solution]}\n\n", mode: 'a')
    end
  end

  def scroll_to_bottom_page(browser)
    loop do
      link_number = browser.links.size
      browser.scroll.to :bottom
      sleep(2)

      return browser if browser.links.size == link_number
    end
  end
end
