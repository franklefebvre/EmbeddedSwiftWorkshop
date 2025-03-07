file(GLOB_RECURSE srcs "src/*.c")

idf_component_register(SRCS "${srcs}"
                       PRIV_INCLUDE_DIRS "./include"
                       INCLUDE_DIRS "./headers"
                       PRIV_REQUIRES bt nvs_flash)
