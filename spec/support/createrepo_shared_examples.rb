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
            'minute'  => '*/10',
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
                'minute'  => '*/10',
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

shared_examples "when groupfile is provided" do
    let :params do
        {
            :groupfile => 'comps.xml',
        }
    end
    it_behaves_like "createrepo command changes", /^\/usr\/bin\/createrepo .* --groupfile comps.xml .*$/
end

shared_examples "when exec timeout is provided" do
    let :params do
        {
            :timeout => 900,
        }
    end
    it "it affects createrepo exec" do
        should contain_exec("createrepo-#{title}").with({
            'timeout' => 900,
        })
    end
    describe "with enable_cron" do
        context "as false" do
            let :params do
                super().merge({
                    :enable_cron => false,
                })
            end
            it "it affects createrepo update exec" do
                should contain_exec("update-createrepo-#{title}").with({
                    'timeout' => 900,
                })
            end
        end
    end
end


shared_examples "when directory should not be managed" do
    let :params do
        {
            :manage_repo_dirs => false,
        }
    end
    it "creates directories" do
        should_not contain_file('/var/yumrepos/testyumrepo')
        should_not contain_file('/var/cache/yumrepos/testyumrepo')
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

shared_examples "when supplying invalid parameters" do
    context "for manage_repo_dirs" do
        let :params do
            {
                :manage_repo_dirs => 'False',
            }
        end

        it 'should fail' do
            expect { subject }.to raise_error(Puppet::Error, /is not a boolean/)
        end
    end
    context "for timeout" do
        let :params do
            {
                :timeout => 'ninehundred',
            }
        end
        it 'should fail' do
            expect { subject }.to raise_error(Puppet::Error, /is not an integer/)
        end
    end
    context "for repository_dir" do
        let :params do
            {
                :repository_dir => "non/absolute/path",
            }
        end

        it 'should fail' do
            expect { subject }.to raise_error(Puppet::Error, /is not an absolute path/)
        end
    end
    context "for repo_cache_dir" do
        let :params do
            {
                :repo_cache_dir => "non/absolute/path",
            }
        end

        it 'should fail' do
            expect { subject }.to raise_error(Puppet::Error, /is not an absolute path/)
        end
    end
    context "for enable_cron" do
        let :params do
            {
                :enable_cron => "false",
            }
        end

        it 'should fail' do
            expect { subject }.to raise_error(Puppet::Error, /is not a boolean/)
        end
    end
    context "for update_file_path" do
        let :params do
            {
                :update_file_path => "non/absolute/path",
            }
        end

        it 'should fail' do
            expect { subject }.to raise_error(Puppet::Error, /is not an absolute path/)
        end
    end
    context "for suppress_cron_stdout" do
        let :params do
            {
                :suppress_cron_stdout => "false",
            }
        end

        it 'should fail' do
            expect { subject }.to raise_error(Puppet::Error, /is not a boolean/)
        end
    end
    context "for suppress_cron_stderr" do
        let :params do
            {
                :suppress_cron_stderr => "false",
            }
        end

        it 'should fail' do
            expect { subject }.to raise_error(Puppet::Error, /is not a boolean/)
        end
    end
end
