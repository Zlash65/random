# Theme by Zlash!

local ret_status="%(?:%{$FG[203]%}➜ :%{$fg_bold[red]%}➜ )"
local equals="%{$FG[203]%}➜"
PROMPT='%{$fg_bold[white]%}${ret_status} %{$FG[113]%}%c%{$reset_color%} $(git_prompt_info)${equals}%{$reset_color%} '

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[cyan]%}git:(%{$FG[067]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[cyan]%}) %{$fg[yellow]%}✗"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[cyan]%})"