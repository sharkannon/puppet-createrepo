require 'spec_helper'

RSpec.configure do |c|
      c.alias_it_should_behave_like_to :it_works_like, 'works'
end

shared_examples "when using default parameters" do
    let :params do
        { }
    end

    it "installs package" do
        should contain_package('createrepo')
    end

    it "creates directories" do
        should contain_file('/var/yumrepos/testyumrepo').with({
            'ensure' => 'directory',
            'owner'  => 'root',
            'group'  => 'root',
            'mode'   => '0775',
        })

        should contain_file('/var/cache/yumrepos/testyumrepo').with({
            'ensure' => 'directory',
            'owner'  => 'root',
            'group'  => 'root',
            'mode'   => '0775',
        })
    end

    # The createrepo command is :osfamily specific
    it "creates repository" do 
        should contain_exec("createrepo-#{title}").with({
            'user'    => 'root',
            'group'   => 'root',
            'creates' => "/var/yumrepos/testyumrepo/repodata",
            'require' => ['Package[createrepo]', "File[/var/yumrepos/testyumrepo]", "File[/var/cache/yumrepos/testyumrepo]"]
        })
    end

    # The createrepo update command is :osfamily specific
    it "updates repository" do
        should contain_cron("update-createrepo-#{title}").with({
            'user'    => 'root',
            'minute'  => '*/1',
            'hour'    => '*',
            'require' => "Exec[createrepo-#{title}]"
        })
    end

    describe "includes update script" do
        it "file" do
            should contain_file("/usr/local/bin/createrepo-update-#{title}").with({
                'ensure' => 'present',
                'owner'  => 'root',
                'group'  => 'root',
                'mode'   => '0755',
            })
        end
        
        # The createrepo update command is :osfamily specific
        it "with correct user check" do
            should contain_file("/usr/local/bin/createrepo-update-#{title}") \
                .with_content(/.*\$\(whoami\) != 'root'.*/) \
                .with_content(/.*You really should be root.*/)
        end
    end
end

shared_examples "when owner and group are provided"  do
    let :params do
        {
            :repo_owner => 'yumuser',
            :repo_group => 'yumgroup',
        }
    end

    it "affects directories" do
        should contain_file('/var/yumrepos/testyumrepo').with({
            'owner' => 'yumuser',
            'group' => 'yumgroup',
        })
        should contain_file('/var/cache/yumrepos/testyumrepo').with({
            'owner' => 'yumuser',
            'group' => 'yumgroup',
        })
    end

    it "affects createrepo exec" do
        should contain_exec("createrepo-#{title}").with({
            'user'  => 'yumuser',
            'group' => 'yumgroup',
        })
    end

    describe "with enable_cron" do
        context "as true" do
            let :params do
                super().merge({
                    :enable_cron => true,
                })
            end
            it "affects cron job" do
                should contain_cron("update-createrepo-#{title}").with({
                    'user' => 'yumuser',
                })
            end
        end
        context "as false" do
            let :params do
                super().merge({
                    :enable_cron => false,
                })
            end
            it "affects update exec" do
                should contain_exec("update-createrepo-#{title}").with({
                    'user'  => 'yumuser',
                    'group' => 'yumgroup',
                })
            end
        end
    end

    describe "affects update script" do
        it "file" do
            should contain_file("/usr/local/bin/createrepo-update-#{title}").with({
                'owner' => 'yumuser',
                'group' => 'yumgroup',
            })
        end
        it "contents" do
            should contain_file("/usr/local/bin/createrepo-update-#{title}") \
                .with_content(/.*\$\(whoami\) != 'yumuser'.*/) \
                .with_content(/.*You really should be yumuser.*/)
        end
    end
end

shared_examples "when repository_dir and repository_cache_dir are provided" do
    let :params do
        {
            :repository_dir => '/var/myrepos/repo1',
            :repo_cache_dir => '/var/cache/myrepos/repo1',
        }
    end

    it "affects directories" do
        should contain_file('/var/myrepos/repo1').with({
            'ensure' => 'directory',
        })
        should contain_file('/var/cache/myrepos/repo1').with({
            'ensure' => 'directory',
        })
    end

    it "affects createrepo exec" do
        should contain_exec("createrepo-#{title}").with({
            'command' => /^\/usr\/bin\/createrepo.*--cachedir \/var\/cache\/myrepos\/repo1.*\/var\/myrepos\/repo1$/
        })
    end

    describe "with enable_cron" do
        context "as true" do
            let :params do
                super().merge({
                    :enable_cron => true,
                })
            end
            it "affects cron job" do
                should contain_cron("update-createrepo-#{title}").with({
                    'command' => /^\/usr\/bin\/createrepo.*--cachedir \/var\/cache\/myrepos\/repo1.*--update \/var\/myrepos\/repo1$/
                })
            end
        end
        context "as false" do
            let :params do
                super().merge({
                    :enable_cron => false,
                })
            end
            it "affects update exec" do
                should contain_exec("update-createrepo-#{title}").with({
                    'command' => /^\/usr\/bin\/createrepo.*--cachedir \/var\/cache\/myrepos\/repo1.*--update \/var\/myrepos\/repo1$/
                })
            end
        end
    end

    describe "affects update script" do
        it "contents" do
            should contain_file("/usr/local/bin/createrepo-update-#{title}") \
                .with_content(/.*\/usr\/bin\/createrepo.*--cachedir \/var\/cache\/myrepos\/repo1.* --update \/var\/myrepos\/repo1.*/)
        end
    end
end

shared_examples "when enable_cron" do |command_line|
    # FIXME figure out a clean way of getting rid of the command_line parameter
    context "is false" do
        let :params do
            { :enable_cron => false }
        end
        it "it should exec createrepo update" do
            should contain_exec("update-createrepo-#{title}").with({
                'command' => "#{command_line}",
                'user'    => 'root',
                'group'   => 'root',
                'require' => "Exec[createrepo-#{title}]"
            })
        end
    end
    context "is true" do
        let :params do
            { :enable_cron => true }
        end
        it "it should contain cron entry" do
            should contain_cron("update-createrepo-#{title}").with({
                'command' => "#{command_line}",
                'user'    => 'root',
                'minute'  => '*/1',
                'hour'    => '*',
                'require' => "Exec[createrepo-#{title}]"
            })
        end
    end
end

shared_examples "when cron schedule is modified" do
    let :params do
        {
            :cron_minute => '30',
            :cron_hour   => '5',
        }
    end

    it "should reflect changes to schedule" do
        should contain_cron("update-createrepo-#{title}").with({
            'minute'  => '30',
            'hour'    => '5',
        })
    end
end

shared_examples "createrepo command changes" do |command_matcher|
    # This shared example takes a regex and matches against all
    # createrepo commands
    it "affects repository creation" do 
        should contain_exec("createrepo-#{title}").with({
            'command' => command_matcher,
        })
    end

    it "affects update script contents" do
        should contain_file("/usr/local/bin/createrepo-update-#{title}") \
            .with_content(command_matcher)
    end

    # FIXME figure out how to refactor this block out of the example,
    # it's mostly redundant code
    describe "with enable_cron" do
        context "as true" do
            let :params do
                super().merge({
                    :enable_cron => true,
                })
            end
            it "affects repo updates via cron" do
                should contain_cron("update-createrepo-#{title}").with({
                    'command' => command_matcher,
                })
            end
        end
        context "as false" do
            let :params do
                super().merge({
                    :enable_cron => false,
                })
            end
            it "affects repo updates via exec" do
                should contain_exec("update-createrepo-#{title}").with({
                    'command' => command_matcher,
                })
            end
        end
    end
end

shared_examples "when suppressing cron output" do
    context "suppress cron stdout only" do
        let :params do
            { :suppress_cron_stdout => true }
        end

        it "suppresses only stdout for cron job" do
            should contain_cron("update-createrepo-#{title}").with({
                'command' => /^.*1>\/dev\/null$/,
            })
            should_not contain_cron("update-createrepo-#{title}").with({
                'command' => /^.*2>\/dev\/null.*$/,
            })
        end
    end
    context "suppress cron stderr only" do
        let :params do
            { :suppress_cron_stderr => true }
        end

        it "suppresses only stderr for cron job" do
            should contain_cron("update-createrepo-#{title}").with({
                'command' => /^.*2>\/dev\/null$/,
            })
            should_not contain_cron("update-createrepo-#{title}").with({
                'command' => /^.*1>\/dev\/null.*$/,
            })
        end
    end
    context "suppress both cron stdout and stderr" do
        let :params do
            {
                :suppress_cron_stdout => true,
                :suppress_cron_stderr => true,
            }
        end

        it "suppresses both stdout and stderr for cron job" do
            should contain_cron("update-createrepo-#{title}").with({
                'command' => /^.*1>\/dev\/null 2>\/dev\/null$/,
            })
        end
    end
end