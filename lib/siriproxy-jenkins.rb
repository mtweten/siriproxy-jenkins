require 'version'
require 'cora'
require 'pp'
require 'text'
require 'rest_client'
require 'siri_objects'
require 'prowl'
require 'uri'

module SiriProxyJenkins
  class SiriProxy::Plugin::Jenkins < SiriProxy::Plugin

    PAGE_SIZE = 4
    SIMILARITY_THRESHOLD = 0.5

    def initialize(config)
      @jenkins_host = URI(config['jenkins_host'])
      user = config['jenkins_user']
      pass = config['jenkins_api_key']

      unless user.nil? || pass.nil?
        @jenkins_host = "#{@jenkins_host.scheme}://#{user}:#{pass}@#{@jenkins_host.host}:#{@jenkins_host.port}#{@jenkins_host.path}"
      end

      @prowl_api_keys = config['prowl_api_keys']
    end

    listen_for /(build[\S]*) (.*)/i do |build_command, job|

      job = correct_siri(build_command, job)
      job_candidates = jobs_that_sound_like(job)

      case job_candidates.size
        when 0 then
          say "I'm sorry, I could not find any builds that sound like '#{job}'."
        when 1 then
          answer = ask "Build '#{job_candidates.first}'?"
          build_job(job_candidates.first) if answer =~ /yes/i
        else
          page_jobs(job_candidates)
      end

      request_completed
    end

    def correct_siri(build_command, job)
      return job.prepend('order ') if build_command =~ /build-to-order/i
      job
    end

    def page_jobs(job_candidates)

      current_page = 0
      continue_paging = nil
      begin
        continue_paging = false

        offset = current_page * PAGE_SIZE

        disambiguation_options = job_candidates[offset, PAGE_SIZE].each_with_index.map do |job_candidate, i|
          create_option("#{i+1}. #{job_candidate}", "Okay, building #{job_candidate}.")
        end

        previous_available = current_page != 0
        disambiguation_options << create_option('Previous') if previous_available

        next_available = current_page < ((job_candidates.size.to_f / PAGE_SIZE.to_f).ceil - 1)
        disambiguation_options << create_option('Next') if next_available

        disambiguation_options << create_option('Cancel')

        answer = ask 'Which job? (say number)', spoken: 'Which job?', disambiguation_options: disambiguation_options

        # Use the metaphone of the word for comparison. Mainly because "four" gets interpreted as "for" by Siri
        case metaphone(answer)
          when metaphone('one')
            build_job(job_candidates[0 + offset])
          when metaphone('two')
            build_job(job_candidates[1 + offset])
          when metaphone('three')
            build_job(job_candidates[2 + offset])
          when metaphone('four')
            build_job(job_candidates[3 + offset])
          when metaphone('next')
            continue_paging = true
            if next_available
              current_page += 1
            end
          when metaphone('previous')
            continue_paging = true
            if previous_available
              current_page -= 1
            end
          when metaphone('cancel')
            say "Okay, I won't trigger any builds."
          else
            continue_paging = true
            say "Sorry, I couldn't understand your response."
        end
      end while continue_paging
    end

    def metaphone(word)
      Text::Metaphone.metaphone(word)
    end

    def create_option(title, selection_text = title, speakable_selection_text=selection_text)
      {
          title: title,
          selectionText: selection_text,
          speakableSelectionText: speakable_selection_text
      }
    end

    def build_job(name)
      say "Okay, building job '#{name}'."

      next_build_number = JSON.parse(RestClient.get("#{@jenkins_host}/job/#{name}/api/json", accept: :json, params: {tree: 'nextBuildNumber'}))['nextBuildNumber']

      # This seems to return a 302 Found on post, and RestClient throws an exception.
      RestClient.post("#{@jenkins_host}/job/#{name}/build", {}) do |response, request, result|
        if response.code == 302
          monitor_job(name, next_build_number)
        else
          puts "Failed to kick off the build: #{response}."
        end
      end
    end

    def monitor_job(name, build_number)

      unless @prowl_api_keys.empty?

        Thread.new do
          build_complete = false
          until build_complete do
            sleep(20)

            fq_build_name = "#{name}/#{build_number}"

            puts "Checking build '#{fq_build_name}'"

            in_queue = JSON.parse(RestClient.get("#{@jenkins_host}/job/#{name}/api/json", accept: :json, params: {tree: 'inQueue'}))['inQueue']
            next if in_queue && (puts("'#{fq_build_name}' is still in the build queue...") || true)

            build_status = JSON.parse(RestClient.get("#{@jenkins_host}/job/#{name}/#{build_number}/api/json/", accept: :json, params: {tree: 'building,result'}))
            next if build_status['building'] && ((puts "'#{fq_build_name}' is still building...") || true)

            puts "'#{fq_build_name}' complete! Notifying..."

            Prowl.add(
                :apikey => @prowl_api_keys.join(','),
                :application => 'Jenkins',
                :description => "Build '#{name}/#{build_number}' finished with status '#{build_status['result']}'.")

            build_complete = true
          end
        end
      end
    end

    def jobs_that_sound_like(job)
      white = Text::WhiteSimilarity.new

      job_words = job.split(' ')

      # I'm sure there is a far better way to do this.
      ranked = all_job_names.map { |name| [white.similarity(job, normalize_job_name(name)), name] }
      candidates = ranked.select { |t| similar_enough?(t[0]) || has_all_words?(t[1], job_words) }.sort.reverse
      puts candidates
      candidates.map { |t| t[1] }
    end

    def all_job_names
      JSON.parse(RestClient.get "#{@jenkins_host}/api/json", accept: :json, params: {tree: 'jobs[name]'})['jobs'].map do |job|
        job['name']
      end
    end

    def normalize_job_name(name)
      name.gsub(/^aeon|-/, 'aeon' => '', '-' => ' ')
    end

    def has_all_words?(target, words)
      words.all? { |word| target.include? word }
    end

    def similar_enough?(similarity)
      similarity >= SIMILARITY_THRESHOLD
    end
  end
end