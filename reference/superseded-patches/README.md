# Parches superados

`0002-input-rsinput-uart-gamepad.patch` (686 lineas, incluye rumble/force-feedback con
`input_ff_create` + `qcom_spmi_haptics_*`) fue NUESTRA version del driver RSInput. El build usa
ahora la version de ROCKNIX dividida en tres parches:

    0031_input--Add-driver-for-RSInput-Gamepad.patch   (driver base)
    1002-input-rsinput-sm8750-ff.patch                 (force feedback)
    1004-input-qcom-hv-haptics-defer-rsinput-playback.patch

Entre los tres cubren lo mismo y aplican sobre 7.2.4. NO anadir 0002 al build: chocaria con 0031.
Se conserva aqui como referencia historica.
