SPACESHIP_PROMPT_ORDER=(
  before_char
  user          # Username section
  dir           # Current directory section
  host          # Hostname section
  git           # Git section (git_branch + git_status)
  hg            # Mercurial section (hg_branch  + hg_status)
  exec_time     # Execution time
  time
  line_sep      # Line break
  after_char
  char
  jobs          # Background jobs indicator
  exit_code     # Exit code section
)

SPACESHIP_PROMPT_FIRST_PREFIX_SHOW=false
SPACESHIP_PROMPT_ADD_NEWLINE=true

SPACESHIP_USER_SHOW=always
SPACESHIP_USER_PREFIX=""

SPACESHIP_TIME_SHOW=true
SPACESHIP_TIME_COLOR=blue

SPACESHIP_CHAR_SYMBOL="❯"
SPACESHIP_CHAR_SUFFIX=" "

SPACESHIP_GIT_BRANCH_PREFIX=""

for file in ~/.config/spaceship/sections/*; do
  source "$file"
done

