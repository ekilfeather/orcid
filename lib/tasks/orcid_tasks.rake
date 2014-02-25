namespace :orcid do
  namespace :batch do
    desc 'Given the input: CSV query for existing Orcids and report to output: CSV'
    task :query => [:environment, :init, :query_runner, :run]

    task :query_runner do
      @runner = lambda { |person|
        puts "Processing: #{person.email}"
        Orcid::ProfileLookupRunner.new {|on|
          on.found {|results|
            person.found(results)
            puts "\tfound" if verbose
          }
          on.not_found {
            person.not_found
            puts "\tnot found" if verbose
          }
        }.call(email: person.email)
      }
    end

    task :create => [:environment, :init, :create_runner, :run]

    task :create_runner do
      @creation_service = lambda {|attributes|
        "@TODO: Extract ProfileCreationRunner from ProfileRequest"
      }
      @runner = lambda { |person|
        puts "Processing: #{person.email}"
        Orcid::ProfileLookupRunner.new {|on|
          on.found {|results|
            person.found(results)
            puts "\tfound" if verbose
          }
          on.not_found {
            person.not_found
            puts "\tnot found" if verbose
            @creation_service.call(person.attributes)
          }
        }.call(email: person.email)
      }
    end


    task :run do
      if defined?(WebMock)
        WebMock.allow_net_connect!
      end
      require 'byebug'; byebug; true;
      input_file = ENV.fetch('input') { './tmp/orcid_input.csv' }
      output_file = ENV.fetch('output') { './tmp/orcid_output.csv' }

      require 'csv'
      CSV.open(output_file, 'wb+') do |output|
        output << @person_builder.to_header_row
        CSV.foreach(input_file, headers: true) do |input|
          person = @person_builder.new(input)
          @runner.call(person)
          output << person.to_output_row
        end
      end
    end

    task :init do
      module Orcid::Batch
        class PersonRecord
          def self.to_header_row
            ['email', 'given_names', 'family_name', 'orcid(s)', 'queried_at']
          end
          attr_reader :email, :given_names, :family_name, :results
          def initialize(row)
            @email = row.fetch('email')
            @given_names = row['given_names']
            @family_name = row['family_name']
            @results = nil
          end

          def attributes
            { email: email, given_names: given_names, family_name: family_name }
          end

          def found(results)
            @results = Array(results).collect(&:orcid_profile_id).join("; ")
          end

          def to_output_row
            [email, given_names, family_name, results, Time.now]
          end

          def not_found
            @results = 'null'
          end
        end
      end
      @person_builder = Orcid::Batch::PersonRecord
    end
  end
end
